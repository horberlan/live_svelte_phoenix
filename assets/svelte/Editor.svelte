<script>
  import BubbleMenuComponent from './menus_editor/BubbleMenu.svelte';
  import { onMount, onDestroy } from 'svelte';
  import { Editor } from '@tiptap/core';
  import BubbleMenu from '@tiptap/extension-bubble-menu';
  import StarterKit from '@tiptap/starter-kit';
  import Placeholder from '@tiptap/extension-placeholder';
  import { CollaborativeClient } from '../js/collaborative_client';
  import { Delta } from '../js/delta';
  import { CollaborationCursor } from '../js/collaboration-cursor';

  export let content = '';
  export let live = null;
  export let docId = 'default-doc';
  export let userId = 'user-' + Math.random().toString(36).substr(2, 9);
  export let userName = 'Anonymous User';
  export let enableCollaboration = true;

  let element;
  let editor;
  let bubbleMenu;
  let collaborativeClient = null;
  let collaborators = [];
  let isConnected = false;

  $: otherCollaborators = collaborators.filter(([id]) => id !== userId);

  const bubbleMenuItems = [
    {
      label: 'H1',
      active: () => ['heading', { level: 1 }],
      command: () => editor.chain().focus().toggleHeading({ level: 1 }).run(),
    },
    {
      label: 'H2',
      active: () => ['heading', { level: 2 }],
      command: () => editor.chain().focus().toggleHeading({ level: 2 }).run(),
    },
    {
      label: 'H3',
      active: () => ['heading', { level: 3 }],
      command: () => editor.chain().focus().toggleHeading({ level: 3 }).run(),
    },
    {
      label: 'P',
      active: () => ['paragraph'],
      command: () => editor.chain().focus().setParagraph().run(),
    },
    {
      label: 'Bold',
      active: () => ['bold'],
      command: () => editor.chain().focus().toggleBold().run(),
    },
    {
      label: 'Italic',
      active: () => ['italic'],
      command: () => editor.chain().focus().toggleItalic().run(),
    },
  ];

  let updateTimeout;
  let isApplyingRemoteChange = false;
  let pendingRemoteChanges = [];
  let processingRemoteChanges = false;

  const intl = {
    placeholder: 'Start typing...',
    connected: 'connected',
    disconnected: 'disconnected',
    statusTitle: (connected, docId, userId) => 
      `Status: ${connected ? 'Connected' : 'Disconnected'} | DocId: ${docId} | UserId: ${userId}`,
    person: 'person',
    people: 'people',
    online: 'online',
    currentlyEditing: 'Currently Editing',
    errorSendingChange: 'Error sending change:',
    errorApplyingUpdate: 'Error applying remote update:',
  };

  function debounceUpdate(newContent) {
    clearTimeout(updateTimeout);
    updateTimeout = setTimeout(() => {
      // Always save to LiveView for persistence
      live.pushEvent('content_updated', { content: newContent });
    }, 300);
  }

  function handleRemoteUpdate(change, remoteUserId, remoteUserName) {
    if (!editor) return;

    pendingRemoteChanges.push({ change, remoteUserId, remoteUserName });
    
    if (!processingRemoteChanges) {
      processRemoteChanges();
    }
  }

  function processRemoteChanges() {
    if (pendingRemoteChanges.length === 0) {
      processingRemoteChanges = false;
      return;
    }

    processingRemoteChanges = true;
    isApplyingRemoteChange = true;

    try {
      // Save current cursor position before applying changes
      const { from, to } = editor.state.selection;
      const cursorPosition = { from, to };
      
      // Get the last (most recent) change
      const { change } = pendingRemoteChanges[pendingRemoteChanges.length - 1];
      pendingRemoteChanges = []; // Clear the queue
      
      if (change.type === 'full_update' && change.content) {
        const currentJSON = editor.getJSON();
        
        if (JSON.stringify(currentJSON) !== JSON.stringify(change.content)) {
          editor.commands.setContent(change.content, false);
          
          requestAnimationFrame(() => {
            if (editor && !editor.isDestroyed) {
              try {
                const docSize = editor.state.doc.content.size;
                const newFrom = Math.min(Math.max(1, cursorPosition.from), docSize - 1);
                const newTo = Math.min(Math.max(1, cursorPosition.to), docSize - 1);
                
                editor.commands.setTextSelection({
                  from: newFrom,
                  to: newTo
                });
              } catch (e) {
                // Ignore positioning errors
              }
            }
          });
        }
      } else {
        // Fallback to deltas (if still using)
        const delta = new Delta(change);
        Delta.applyToTiptap(editor, delta);
        
        const adjustedPosition = adjustCursorPosition(delta, cursorPosition);
        requestAnimationFrame(() => {
          if (editor && !editor.isDestroyed) {
            try {
              editor.commands.setTextSelection({
                from: adjustedPosition.from,
                to: adjustedPosition.to
              });
            } catch (e) {
              // Ignore errors
            }
          }
        });
      }
    } catch (error) {
      console.error(intl.errorApplyingUpdate, error);
    } finally {
      isApplyingRemoteChange = false;
      processingRemoteChanges = false;
    }
  }

  function adjustCursorPosition(delta, cursorPosition) {
    // Use Delta's transformIndex function to calculate the new position
    const newFrom = Delta.transformIndex(cursorPosition.from, delta, false);
    const newTo = Delta.transformIndex(cursorPosition.to, delta, false);
    
    return {
      from: Math.max(1, newFrom),
      to: Math.max(1, newTo)
    };
  }

  function handleCollaboratorChange(collaboratorsList) {
    const uniqueCollaborators = new Map();
    
    collaboratorsList.forEach(([id, info]) => {
      if (!uniqueCollaborators.has(id)) {
        uniqueCollaborators.set(id, info);
      }
    });
    
    collaborators = Array.from(uniqueCollaborators.entries());
  }

  async function initializeCollaboration() {
    if (!enableCollaboration) return;

    try {
      collaborativeClient = new CollaborativeClient(
        docId,
        userId,
        userName,
        handleRemoteUpdate,
        handleCollaboratorChange
      );

      const response = await collaborativeClient.connect();
      isConnected = true;

      const statusInterval = setInterval(() => {
        if (collaborativeClient) {
          const newStatus = collaborativeClient.getConnectionStatus();
          if (newStatus !== isConnected) {
            isConnected = newStatus;
          }
        }
      }, 1000);

      onDestroy(() => clearInterval(statusInterval));

      if (response.contents) {
        if (response.contents.type === 'full_update' && response.contents.content) {
          // Content in TipTap JSON format
          editor.commands.setContent(response.contents.content, false);
        } else if (response.contents.length > 0) {
          // Content in Delta format (fallback)
          const delta = new Delta(response.contents);
          Delta.applyToTiptap(editor, delta);
        }
      }
    } catch (error) {
      isConnected = false;
    }
  }

  onMount(() => {
    editor = new Editor({
      element: element,
      extensions: [
        StarterKit,
        BubbleMenu.configure({
          element: bubbleMenu,
        }),
        Placeholder.configure({
          placeholder: intl.placeholder,
        }),
        CollaborationCursor,
      ],
      editorProps: {
        attributes: {
          class: 'prose max-w-none prose-sm sm:prose-base m-5 p-4 focus:outline-none bg-base-200 shadow-md rounded-lg',
        },
      },
      content,
      onTransaction: () => {
        editor = editor;
      },
      onUpdate: ({ editor, transaction }) => {
        const isRemote = transaction.getMeta('isRemote');
        if (isRemote || isApplyingRemoteChange) return;

        const newContent = editor.getHTML();
        
        // Save to database via LiveView
        debounceUpdate(newContent);

        if (collaborativeClient && isConnected && transaction.docChanged) {
          try {
            const documentJSON = editor.getJSON();
            collaborativeClient.sendChange({ type: 'full_update', content: documentJSON });
          } catch (error) {
            console.error(intl.errorSendingChange, error);
          }
        }
      },
      onSelectionUpdate: ({ editor }) => {
        if (collaborativeClient && isConnected) {
          const { from, to } = editor.state.selection;
          collaborativeClient.sendCursorUpdate({ from, to });
        }
      },
    });

    if (enableCollaboration) {
      initializeCollaboration();
    } else {
      // Only for non-collaborative mode (fallback)
      live.handleEvent('remote_content_updated', (data) => {
        if (editor && data.content !== editor.getHTML()) {
          const { from, to } = editor.state.selection;
          editor.commands.setContent(data.content, false);
          // Try to restore cursor position
          requestAnimationFrame(() => {
            if (editor && !editor.isDestroyed) {
              editor.commands.setTextSelection({ from, to });
            }
          });
        }
      });
    }
  });

  onDestroy(() => {
    if (collaborativeClient) {
      collaborativeClient.disconnect();
    }
    if (editor) {
      editor.destroy();
    }
  });
</script>

<div class="relative mb-4">
  <BubbleMenuComponent {editor} {bubbleMenuItems} />
  {#if bubbleMenuItems.length > 0}
    <div class="flex gap-2 bg-base-100 p-2 rounded-lg shadow-sm" bind:this={bubbleMenu}>
      {#if editor}
        {#each bubbleMenuItems as item}
          <button
            on:click={item.command}
            class:active={editor.isActive(...item.active())}
            class="{editor.isActive(...item.active()) ? 'bg-neutral text-base-100 hover:bg-neutral' : 'bg-base-200'} px-2 py-1 rounded-md hover:bg-base-300"
          >
            {item.label}
          </button>
        {/each}
      {/if}
    </div>
  {/if}

  <div bind:this={element} class="w-full" />
</div>