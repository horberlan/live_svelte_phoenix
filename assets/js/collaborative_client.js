import { Socket } from 'phoenix';

export class CollaborativeClient {
    constructor(documentId, userId, userName, onUpdateCallback, onCollaboratorChangeCallback, onCursorUpdateCallback = null) {
        this.documentId = documentId;
        this.userId = userId;
        this.userName = userName;

        this.onUpdateCallback = onUpdateCallback;
        this.onCollaboratorChangeCallback = onCollaboratorChangeCallback;
        this.onCursorUpdateCallback = onCursorUpdateCallback;

        this.socket = null;
        this.channel = null;
        this.isConnected = false;

        this.documentVersion = 0;
        this.collaborators = new Map();

        this.pendingChanges = [];
        this.isApplyingRemoteChange = false;
    }

    getConnectionStatus() {
        return this.isConnected &&
            this.channel &&
            this.channel.state === 'joined';
    }

    async connect() {
        return new Promise((resolve, reject) => {
            this.socket = new Socket('/socket', {
                params: { token: this.userId },
            });

            this.socket.connect();

            this.channel = this.socket.channel(`document:${this.documentId}`, {
                user_id: this.userId,
                user_name: this.userName,
            });

            this.channel.on('remote_update', (payload) => {
                this.handleRemoteUpdate(payload);
            });

            this.channel.on('remote_cursor', (payload) => {
                this.handleRemoteCursor(payload);
            });

            this.channel.on('collaborator_joined', (payload) => {
                this.handleCollaboratorJoined(payload);
            });

            this.channel.on('collaborator_left', (payload) => {
                this.handleCollaboratorLeft(payload);
            });

            this.channel.on('document_updated', (payload) => {
                this.handleDocumentUpdated(payload);
            });

            this.channel.on('presence_state', (state) => {
                this.handlePresenceState(state);
            });

            this.channel.on('presence_diff', (diff) => {
                this.handlePresenceDiff(diff);
            });

            this.channel
                .join()
                .receive('ok', (response) => {
                    this.version = response.version;
                    this.collaborators = new Map(Object.entries(response.collaborators || {}));
                    this.isConnected = true;
                    resolve(response);
                })
                .receive('error', (response) => {
                    this.isConnected = false;
                    reject(response);
                })
                .receive('timeout', () => {
                    this.isConnected = false;
                    reject(new Error('Connection timeout'));
                });
        });
    }

    disconnect() {
        this.isConnected = false;
        if (this.channel) {
            this.channel.leave();
        }
        if (this.socket) {
            this.socket.disconnect();
        }
    }

    sendChange(changeData) {
        if (this.isApplyingRemoteChange) {
            return;
        }

        const change = changeData.toJSON ? changeData.toJSON() : changeData;

        this.channel
            .push('update', {
                change: change,
                version: this.version,
            })
            .receive('ok', (response) => {
                this.version = response.version;
            })
            .receive('error', (response) => {
                console.error('[CollaborativeClient] Error sending change:', response);
            });
    }

    sendCursorUpdate(position) {
        if (!this.channel) return;

        this.channel.push('cursor_update', {
            position: position,
        });
    }

    async getHistory() {
        return new Promise((resolve, reject) => {
            this.channel
                .push('get_history', {})
                .receive('ok', (response) => {
                    resolve(response.history);
                })
                .receive('error', (response) => {
                    reject(response);
                });
        });
    }

    async undo() {
        return new Promise((resolve, reject) => {
            this.channel
                .push('undo', {})
                .receive('ok', (response) => {
                    this.version = response.version;
                    resolve(response);
                })
                .receive('error', (response) => {
                    reject(response);
                });
        });
    }

    handleRemoteUpdate(payload) {
        if (payload.user_id === this.userId) {
            return;
        }

        this.isApplyingRemoteChange = true;
        this.version = payload.version;

        if (this.onUpdateCallback) {
            this.onUpdateCallback(payload.change, payload.user_id, payload.user_name);
        }

        this.isApplyingRemoteChange = false;
    }

    handleRemoteCursor(payload) {
        if (payload.user_id === this.userId) return;

        const collaborator = this.collaborators.get(payload.user_id) || {};
        collaborator.cursor_position = payload.position;
        collaborator.user_name = payload.user_name;
        this.collaborators.set(payload.user_id, collaborator);

        if (this.onCollaboratorChangeCallback) {
            this.onCollaboratorChangeCallback(Array.from(this.collaborators.entries()));
        }

        if (this.onCursorUpdateCallback) {
            this.onCursorUpdateCallback(payload.user_id, payload.position, payload.user_name);
        }
    }

    handleCollaboratorJoined(payload) {
        this.collaborators.set(payload.user_id, {
            name: payload.user_name,
            cursor_position: null,
        });

        if (this.onCollaboratorChangeCallback) {
            this.onCollaboratorChangeCallback(Array.from(this.collaborators.entries()));
        }
    }

    handleCollaboratorLeft(payload) {
        this.collaborators.delete(payload.user_id);

        if (this.onCollaboratorChangeCallback) {
            this.onCollaboratorChangeCallback(Array.from(this.collaborators.entries()));
        }
    }

    handleDocumentUpdated(payload) {
        this.version = payload.version;

        if (this.onUpdateCallback) {
            this.onUpdateCallback(payload.contents, payload.user_id, null, true);
        }
    }

    handlePresenceState(state) {
        this.collaborators.clear();
        Object.keys(state).forEach((userId) => {
            const metas = state[userId].metas;
            if (metas && metas.length > 0) {
                const meta = metas[0];
                this.collaborators.set(userId, {
                    name: meta.user_name,
                    online_at: meta.online_at,
                });
            }
        });

        if (this.onCollaboratorChangeCallback) {
            this.onCollaboratorChangeCallback(Array.from(this.collaborators.entries()));
        }
    }

    handlePresenceDiff(diff) {
        if (diff.joins) {
            Object.keys(diff.joins).forEach((userId) => {
                const metas = diff.joins[userId].metas;
                if (metas && metas.length > 0) {
                    const meta = metas[0];
                    this.collaborators.set(userId, {
                        name: meta.user_name,
                        online_at: meta.online_at,
                    });
                }
            });
        }

        if (diff.leaves) {
            Object.keys(diff.leaves).forEach((userId) => {
                this.collaborators.delete(userId);
            });
        }

        if (this.onCollaboratorChangeCallback) {
            this.onCollaboratorChangeCallback(Array.from(this.collaborators.entries()));
        }
    }
}
