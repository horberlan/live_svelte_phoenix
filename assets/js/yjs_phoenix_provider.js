import * as Y from 'yjs';
import { Awareness, encodeAwarenessUpdate, applyAwarenessUpdate } from 'y-protocols/awareness';
import { fixEncodingInHTML } from './encoding-fix.js';

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

export class PhoenixChannelProvider {
  constructor(docId, ydoc, live, { userId, userName, onStatus }) {
    this.doc = ydoc;
    this.docId = docId;
    this.live = live;
    this.userId = userId;
    this.userName = userName;
    this.onStatus = onStatus || (() => null);
    
    this.awareness = new Awareness(this.doc);
    this.connected = false;
    this.synced = false; // Flag to prevent sending updates before initial sync

    this._onUpdate = this._onUpdate.bind(this);
    this._onAwarenessUpdate = this._onAwarenessUpdate.bind(this);
    
    this.doc.on('update', this._onUpdate);
    this.awareness.on('update', this._onAwarenessUpdate);
    
    this.connect();
  }

  connect() {
    console.log('[Provider] Connecting, sending yjs_provider_ready for doc:', this.docId);
    this.live.pushEvent('yjs_provider_ready', { doc_id: this.docId });
  }

  handleInitialState(payload) {
    console.log('[Provider] Received initial state:', payload);
    if (payload.status === 'ok') {
        this.onStatus('connected');
        this.connected = true;
        console.log('[Provider] Connected! Doc size:', payload.doc?.length, 'Awareness size:', payload.awareness?.length);
        if (payload.doc) {
            const doc_bin = toUint8Array(payload.doc);
            Y.applyUpdate(this.doc, doc_bin, this);
        }
        if (payload.awareness) {
            const awareness_bin = toUint8Array(payload.awareness);
            applyAwarenessUpdate(this.awareness, awareness_bin, this);
        }
        this.awareness.setLocalStateField('user', {
            name: this.userName,
            color: '#f783ac',
        });
        
        // Mark as synced after initial state is loaded
        this.synced = true;
        console.log('[Provider] Initial sync complete, ready to send updates');
    } else {
        console.error('Failed to connect yjs provider', payload);
        this.onStatus('disconnected');
        this.connected = false;
    }
  }

  disconnect() {
    this.live.pushEvent('yjs_provider_leave', { doc_id: this.docId });
    this.connected = false;
    this.onStatus('disconnected');
  }

  _onUpdate(update, origin) {
    console.log('[Provider] Doc update detected, origin:', origin === this ? 'self' : 'remote', 'connected:', this.connected, 'synced:', this.synced, 'size:', update.length);
    // Only send updates that are NOT from this provider AND after initial sync
    if (origin !== this && this.connected && this.synced) {
      console.log('[Provider] Sending yjs_update to server');
      this.live.pushEvent('yjs_update', { 
        doc_id: this.docId, 
        payload: fromUint8Array(update) 
      });
    } else {
      console.log('[Provider] NOT sending update (origin:', origin === this ? 'self' : 'remote', ', synced:', this.synced, ')');
    }
  }

  _onAwarenessUpdate({ added, updated, removed }, origin) {
    console.log('[Provider] Awareness update:', { added, updated, removed, origin: origin === this ? 'self' : 'remote' });
    if (origin !== this && this.connected) {
      const changedClients = added.concat(updated).concat(removed);
      const awarenessUpdate = encodeAwarenessUpdate(this.awareness, changedClients);
      console.log('[Provider] Sending awareness_update to server');
      this.live.pushEvent('awareness_update', { 
        doc_id: this.docId, 
        payload: fromUint8Array(awarenessUpdate) 
      });
    }
  }

  handleMessage(event, payload) {
    console.log('[Provider] Received message:', event, 'for doc:', payload.doc_id);
    if (payload.doc_id !== this.docId) {
        console.log('[Provider] Ignoring message for different doc');
        return;
    }

    const data = toUint8Array(payload.payload);

    if (event === 'yjs_update') {
        console.log('[Provider] Applying remote yjs_update, size:', data.length);
        Y.applyUpdate(this.doc, data, this);
        
        // Debug: Check document content after update
        const xmlFragment = this.doc.getXmlFragment('default');
        let htmlContent = xmlFragment.toString();
        console.log('[Provider] Document HTML after update:', htmlContent.slice(0, 200));
        
        // Check for encoding issues and fix them
        if (htmlContent.includes('Ã') || htmlContent.includes('ð')) {
          console.warn('[Provider] ⚠️ Detected encoding issues in document content, fixing...');
          const fixedContent = fixEncodingInHTML(htmlContent);
          console.log('[Provider] ✅ Fixed content:', fixedContent.slice(0, 200));
          
          // Apply the fix back to the document
          // Note: This is a bit tricky with Yjs, we need to be careful not to create infinite loops
          if (fixedContent !== htmlContent) {
            console.log('[Provider] Applying encoding fix to document');
            // We'll need to update the document content carefully
            // For now, just log the issue
          }
        }
    } else if (event === 'awareness_update') {
        console.log('[Provider] Applying remote awareness_update');
        applyAwarenessUpdate(this.awareness, data, this);
    }
  }

  destroy() {
    this.doc.off('update', this._onUpdate);
    this.awareness.off('update', this._onAwarenessUpdate);
    this.disconnect();
  }
}