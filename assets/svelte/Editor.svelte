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
  export let userId = '';
  export let userName = '';
  export let enableCollaboration = true;

  let element;
  let editor;
  let bubbleMenu;
  let collaborativeClient = null;
  let isConnected = false;
  let statusInterval;

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
  let pendingChanges = []; // To track local changes not yet ack'd by the server

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

  function handleRemoteUpdate(change, remoteUserId, remoteUserName, htmlContent, isFullUpdate = false) {
    if (!editor) return;

    const updatedPending = [];
    let remoteDelta = new Delta(change.content || change);

    // Transform the remote delta against all pending local changes
    for (const pendingDelta of pendingChanges) {
        const transformedRemote = Delta.transform(remoteDelta, pendingDelta, false);
        const transformedPending = Delta.transform(pendingDelta, remoteDelta, true);
        remoteDelta = transformedRemote;
        updatedPending.push(transformedPending);
    }

    if (updatedPending.length > 0) {
      pendingChanges = updatedPending;
    }

    pendingRemoteChanges.push({
      change: { content: remoteDelta.toJSON() },
      html: htmlContent,
      remoteUserId,
      remoteUserName,
      isFullUpdate
    });
    
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
    
    // Take the next change from the queue
    const { change, html, isFullUpdate } = pendingRemoteChanges.shift();

    isApplyingRemoteChange = true;
    try {
      const { from, to } = editor.state.selection;
      const cursorPosition = { from, to };
      
      const delta = new Delta(change.content);
      Delta.applyToTiptap(editor, delta);

      if (typeof html === 'string' && html.length > 0) {
        const currentHtml = editor.getHTML();
        if (currentHtml !== html) {
          isApplyingRemoteChange = true;
          editor.commands.setContent(html, false);
          isApplyingRemoteChange = false;
        }
      } else if (isFullUpdate && change && Array.isArray(change.content)) {
        // As a fallback for full updates without HTML, rebuild content entirely
        const fullDelta = new Delta(change.content);
        editor.commands.setContent('', false);
        Delta.applyToTiptap(editor, fullDelta);
      }
      
      const adjustedPosition = adjustCursorPosition(delta, cursorPosition);
      requestAnimationFrame(() => {
        if (editor && !editor.isDestroyed) {
          try {
            // Only adjust selection if the editor doesn't have focus.
            // If it has focus, the user is typing, and we don't want to move their cursor.
            if (!editor.isFocused) {
              editor.commands.setTextSelection({ from: adjustedPosition.from, to: adjustedPosition.to });
            }
          } catch (e) {
            // Ignore errors: can happen if selection is out of bounds during rapid changes
          }
        }
      });
    } catch (error) {
      console.error(intl.errorApplyingUpdate, error);
    } finally {
      isApplyingRemoteChange = false;
      
      // If there are more changes, process them in the next animation frame
      // to avoid blocking the main thread and allow UI to update.
      if (pendingRemoteChanges.length > 0) {
        requestAnimationFrame(processRemoteChanges);
      } else {
        processingRemoteChanges = false;
      }
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

  async function initializeCollaboration() {
    if (!enableCollaboration) return;

    try {
      collaborativeClient = new CollaborativeClient(
        docId,
        userId,
        userName,
        handleRemoteUpdate,
        () => {
          // The collaboration-cursor plugin now handles collaborator updates automatically
        }
      );

      const response = await collaborativeClient.connect();
      isConnected = true;

      statusInterval = setInterval(() => {
        if (collaborativeClient) {
          const newStatus = collaborativeClient.getConnectionStatus();
          if (newStatus !== isConnected) {
            isConnected = newStatus;
          }
        }
      }, 1000);

      return response;
    } catch (error) {
      console.error('Failed to initialize collaboration:', error);
      isConnected = false;
      return null;
    }
  }

  let themeColors = [];

  function getThemeColors() {
    if (typeof window === 'undefined') return [];
    const style = getComputedStyle(document.documentElement);
    return [
      `hsl(${style.getPropertyValue('--p')})`,
      `hsl(${style.getPropertyValue('--s')})`,
      `hsl(${style.getPropertyValue('--a')})`,
      `hsl(${style.getPropertyValue('--n')})`,
      `hsl(${style.getPropertyValue('--in')})`,
      `hsl(${style.getPropertyValue('--su')})`,
      `hsl(${style.getPropertyValue('--wa')})`,
      `hsl(${style.getPropertyValue('--er')})`,
    ];
  }

  onMount(async () => {
    themeColors = getThemeColors();

    let initialContents = null;
    let initialHtml = null;
    if (enableCollaboration) {
      const initialState = await initializeCollaboration();
      if (initialState) {
        initialContents = initialState.contents;
        initialHtml = initialState.html;
      }
    }
    
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
        CollaborationCursor.configure({
          client: collaborativeClient,
          themeColors: themeColors,
        }),
      ],
      editorProps: {
        attributes: {
          class: 'prose max-w-none prose-sm sm:prose-base m-5 p-4 focus:outline-none bg-base-200 shadow-md rounded-lg',
        },
      },
      content: enableCollaboration ? '' : content,
      onTransaction: () => {
        editor = editor;
      },
      onUpdate: ({ editor, transaction }) => {
        const isRemote = transaction.getMeta('isRemote');
        if (isRemote || isApplyingRemoteChange || (collaborativeClient && collaborativeClient.isApplyingRemoteChange)) return;

        const newContent = editor.getHTML();
        
        // Save to database via LiveView
        debounceUpdate(newContent);

        if (collaborativeClient && isConnected && transaction.docChanged) {
          try {
            const delta = Delta.fromTiptapTransaction(editor.state.doc, transaction);
            const ops = delta.toJSON();
            if (ops.length > 0) {
              pendingChanges.push(delta);
              collaborativeClient.sendChange({ type: 'delta', content: ops }, newContent, () => {
                pendingChanges.shift();
              });
            }
          } catch (error) {
            console.error(intl.errorSendingChange, error);
          }
        }
      },
      onSelectionUpdate: ({ editor }) => {
        if (collaborativeClient && isConnected && collaborativeClient.collaborators.size > 1) {
          const { from, to } = editor.state.selection;
          collaborativeClient.sendCursorUpdate({ from, to });
        }
      },
    });

    if (initialContents && initialContents.length > 0) {
      const delta = new Delta(initialContents);
      Delta.applyToTiptap(editor, delta);
    } else if (initialHtml) {
      editor.commands.setContent(initialHtml, true);
    } else if (content) {
      editor.commands.setContent(content, true);
    }

    if (!enableCollaboration) {
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
    if (statusInterval) {
      clearInterval(statusInterval);
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
            class="{editor.isActive(...item.active()) ? 'bg-neutral text-base-100 hover:bg-neutral' : 'bg-base-200'} px-2 py-1 rounded-md hover:bg-base-300">
            {item.label}
          </button>
        {/each}
      {/if}
    </div>
  {/if}

  <div bind:this={element} class="w-full" />
</div>