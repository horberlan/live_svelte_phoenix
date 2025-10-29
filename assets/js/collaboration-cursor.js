import { Extension } from '@tiptap/core';
import { Plugin, PluginKey } from '@tiptap/pm/state';

export const CollaborationCursor = Extension.create({
  name: 'collaborationCursor',

  addStorage() {
    return {
      cursorPos: null,
      isRemoteUpdate: false,
    };
  },

  addProseMirrorPlugins() {
    const storage = this.storage;

    return [
      new Plugin({
        key: new PluginKey('collaborationCursor'),
        
        appendTransaction: (transactions, oldState, newState) => {
          const isRemote = transactions.some(tr => tr.getMeta('isRemote'));
          
          if (isRemote) {
            return null;
          }

          storage.cursorPos = {
            anchor: newState.selection.anchor,
            head: newState.selection.head,
          };

          return null;
        },

        filterTransaction: (transaction, state) => {
          const isRemote = transaction.getMeta('isRemote');
          
          if (isRemote && storage.cursorPos) {
            transaction.setMeta('restoreCursor', storage.cursorPos);
          }

          return true;
        },
      }),
    ];
  },
});
