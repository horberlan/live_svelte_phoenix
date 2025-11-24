import * as Y from 'yjs';
import { Awareness, encodeAwarenessUpdate, applyAwarenessUpdate } from 'y-protocols/awareness';
import { Socket } from 'phoenix';

// Helper to send binary data over Phoenix channels
function fromUint8Array(arr) {
  return btoa(String.fromCharCode.apply(null, arr));
}

function toUint8Array(str) {
  try {
    return new Uint8Array(atob(str).split('').map(c => c.charCodeAt(0)));
  } catch (e) {
    console.error('Failed to decode base64 string:', e);
    return new Uint8Array();
  }
}

export class YjsChannelProvider {
  constructor(docId, ydoc, { userId, userName, onStatus }) {
    this.doc = ydoc;
    this.docId = docId;
    this.userId = userId;
    this.userName = userName;
    this.onStatus = onStatus || (() => null);
    
    this.awareness = new Awareness(this.doc);
    this.connected = false;
    this.synced = false;

    this._onUpdate = this._onUpdate.bind(this);
    this._onAwarenessUpdate = this._onAwarenessUpdate.bind(this);
    
    this.doc.on('update', this._onUpdate);
    this.awareness.on('update', this._onAwarenessUpdate);
    
    this.connect();
  }

  connect() {
    console.log('[YjsChannelProvider] Connecting to channel yjs:' + this.docId);
    
    this.socket = new Socket('/socket', {
      params: { token: this.userId },
    });

    this.socket.connect();

    this.channel = this.socket.channel(`yjs:${this.docId}`, {});

    this.channel.on('yjs_update', (payload) => {
      console.log('[YjsChannelProvider] Received yjs_update from server');
      this.handleUpdate(payload);
    });

    this.channel.on('awareness_update', (payload) => {
      console.log('[YjsChannelProvider] Received awareness_update from server');
      this.handleAwarenessUpdate(payload);
    });

    this.channel.join()
      .receive('ok', (response) => {
        console.log('[YjsChannelProvider] Joined successfully', response);
        this.connected = true;
        this.onStatus('connected');
        
        // Apply initial state
        if (response.doc) {
          const doc_bin = toUint8Array(response.doc);
          Y.applyUpdate(this.doc, doc_bin, this);
        }
        if (response.awareness) {
          const awareness_bin = toUint8Array(response.awareness);
          applyAwarenessUpdate(this.awareness, awareness_bin, this);
        }
        
        // Set local user info
        this.awareness.setLocalStateField('user', {
          name: this.userName,
          color: '#f783ac',
        });
        
        // Mark as synced
        this.synced = true;
        console.log('[YjsChannelProvider] Initial sync complete');
      })
      .receive('error', (resp) => {
        console.error('[YjsChannelProvider] Failed to join', resp);
        this.onStatus('disconnected');
      });
  }

  handleUpdate(payload) {
    if (payload.doc_id !== this.docId) {
      return;
    }

    const data = toUint8Array(payload.payload);
    console.log('[YjsChannelProvider] Applying remote update, size:', data.length);
    Y.applyUpdate(this.doc, data, this);
  }

  handleAwarenessUpdate(payload) {
    if (payload.doc_id !== this.docId) {
      return;
    }

    const data = toUint8Array(payload.payload);
    console.log('[YjsChannelProvider] Applying remote awareness update');
    applyAwarenessUpdate(this.awareness, data, this);
  }

  _onUpdate(update, origin) {
    console.log('[YjsChannelProvider] Doc update, origin:', origin === this ? 'self' : 'other', 'synced:', this.synced);
    
    if (origin !== this && this.connected && this.synced) {
      console.log('[YjsChannelProvider] Sending update to server, size:', update.length);
      this.channel.push('yjs_update', {
        payload: fromUint8Array(update)
      });
    }
  }

  _onAwarenessUpdate({ added, updated, removed }, origin) {
    console.log('[YjsChannelProvider] Awareness update:', { added, updated, removed });
    
    if (origin !== this && this.connected && this.synced) {
      const changedClients = added.concat(updated).concat(removed);
      const awarenessUpdate = encodeAwarenessUpdate(this.awareness, changedClients);
      console.log('[YjsChannelProvider] Sending awareness update to server');
      this.channel.push('awareness_update', {
        payload: fromUint8Array(awarenessUpdate)
      });
    }
  }

  disconnect() {
    console.log('[YjsChannelProvider] Disconnecting...')
    
    // Limpar o awareness local antes de desconectar
    if (this.awareness) {
      console.log('[YjsChannelProvider] Clearing local awareness state')
      this.awareness.setLocalState(null)
    }
    
    if (this.channel) {
      this.channel.leave();
    }
    if (this.socket) {
      this.socket.disconnect();
    }
    this.connected = false;
    this.synced = false;
    this.onStatus('disconnected');
  }

  destroy() {
    console.log('[YjsChannelProvider] Destroying provider')
    
    // Remover listeners
    this.doc.off('update', this._onUpdate);
    this.awareness.off('update', this._onAwarenessUpdate);
    
    // Desconectar (isso vai limpar o awareness)
    this.disconnect();
    
    // Destruir o awareness
    if (this.awareness) {
      this.awareness.destroy();
    }
  }
}
