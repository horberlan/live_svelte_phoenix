import { Extension } from '@tiptap/core';
import { Plugin, PluginKey } from '@tiptap/pm/state';
import { Decoration, DecorationSet } from '@tiptap/pm/view';

const CURSOR_COLORS = [
  { bg: 'bg-primary', text: 'text-primary-content', border: 'border-primary' },
  { bg: 'bg-secondary', text: 'text-secondary-content', border: 'border-secondary' },
  { bg: 'bg-accent', text: 'text-accent-content', border: 'border-accent' },
  { bg: 'bg-info', text: 'text-info-content', border: 'border-info' },
  { bg: 'bg-success', text: 'text-success-content', border: 'border-success' },
  { bg: 'bg-warning', text: 'text-warning-content', border: 'border-warning' },
  { bg: 'bg-error', text: 'text-error-content', border: 'border-error' },
];

function getUserColor(userId) {
  let hash = 0;
  for (let i = 0; i < userId.length; i++) {
    hash = userId.charCodeAt(i) + ((hash << 5) - hash);
  }
  return CURSOR_COLORS[Math.abs(hash) % CURSOR_COLORS.length];
}

function createCursorElement(userId, userName, color) {
  const cursor = document.createElement('span');
  cursor.className = `collaboration-cursor ${color.border} border-l-2 relative`;
  cursor.style.cssText = 'position: absolute; pointer-events: none; z-index: 10;';
  
  const label = document.createElement('span');
  label.className = `${color.bg} ${color.text} text-xs px-2 py-0.5 rounded-t absolute -top-5 whitespace-nowrap font-medium shadow-sm cursor-label`;
  // Show userId if userName is "Anonymous User" or empty
  const displayName = (userName && userName !== 'Anonymous User') ? userName : userId;
  label.textContent = displayName;
  
  setTimeout(() => {
    const rect = label.getBoundingClientRect();
    const viewportWidth = window.innerWidth;
    
    if (rect.right > viewportWidth - 10) {
      label.style.left = 'auto';
      label.style.right = '0';
    } else {
      label.style.left = '0';
      label.style.right = 'auto';
    }
  }, 0);
  
  cursor.appendChild(label);
  return cursor;
}

export const CollaborationCursor = Extension.create({
  name: 'collaborationCursor',

  addOptions() {
    return {
      remoteCursors: new Map(), // Map<userId, {position, userName}>
      onCursorUpdate: null,
    };
  },

  addStorage() {
    return {
      cursorPos: null,
      decorations: DecorationSet.empty,
    };
  },

  addProseMirrorPlugins() {
    const extension = this;

    return [
      new Plugin({
        key: new PluginKey('collaborationCursor'),

        state: {
          init() {
            return DecorationSet.empty;
          },

          apply(tr, decorationSet, _oldState, newState) {
            // Update decorations based on remote cursors
            const remoteCursors = extension.options.remoteCursors;
            const decorations = [];

            remoteCursors.forEach((cursorData, userId) => {
              const { position, userName } = cursorData;
              
              if (position && position.from !== undefined) {
                const color = getUserColor(userId);
                const pos = Math.min(position.from, newState.doc.content.size);
                
                if (pos >= 0 && pos <= newState.doc.content.size) {
                  const widget = Decoration.widget(pos, () => {
                    return createCursorElement(userId, userName, color);
                  }, {
                    side: 1,
                    key: `cursor-${userId}`,
                  });
                  
                  decorations.push(widget);
                }
              }
            });

            return DecorationSet.create(newState.doc, decorations);
          },
        },

        props: {
          decorations(state) {
            return this.getState(state);
          },
        },

        appendTransaction: (transactions, _oldState, newState) => {
          const isRemote = transactions.some(tr => tr.getMeta('isRemote'));

          if (isRemote) {
            return null;
          }

          extension.storage.cursorPos = {
            anchor: newState.selection.anchor,
            head: newState.selection.head,
          };

          return null;
        },
      }),
    ];
  },

  addCommands() {
    return {
      updateRemoteCursor: (userId, position, userName) => ({ editor }) => {
        this.options.remoteCursors.set(userId, { position, userName });
        editor.view.dispatch(editor.state.tr);
        return true;
      },

      removeRemoteCursor: (userId) => ({ editor }) => {
        this.options.remoteCursors.delete(userId);
        editor.view.dispatch(editor.state.tr);
        return true;
      },

      clearRemoteCursors: () => ({ editor }) => {
        this.options.remoteCursors.clear();
        editor.view.dispatch(editor.state.tr);
        return true;
      },
    };
  },
});
