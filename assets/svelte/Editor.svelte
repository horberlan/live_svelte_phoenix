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
  let isInitializing = true; // Flag to prevent saving during initialization
  let initialContentApplied = false; // Flag to ensure initial content is applied only once
  let initialVersion = null; // Version received on initial join - used to filter outdated updates

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
    // In collaborative mode, persistence is handled by the delta system
    // Only save via LiveView in non-collaborative mode or when disconnected
    if (enableCollaboration && collaborativeClient && isConnected) {
      return;
    }
    
    clearTimeout(updateTimeout);
    updateTimeout = setTimeout(() => {
      // Save to LiveView for persistence (fallback mode)
      live.pushEvent('content_updated', { content: newContent });
    }, 300);
  }

  function handleRemoteUpdate(change, remoteUserId, remoteUserName, htmlContent, isFullUpdate = false, remoteVersion = null) {
    if (!editor || !collaborativeClient) return;
    
    // Ignore updates from self (should be handled by collaborative_client, but double-check)
    if (remoteUserId === userId) {
      console.log('[Editor] Ignoring update from self');
      return;
    }
    
    // During initialization, queue updates but don't process them yet
    // We'll process them after initialization is complete
    if (isInitializing) {
      console.log('[Editor] Queuing remote update during initialization from', remoteUserId, 'version:', remoteVersion);
      pendingRemoteChanges.push({
        change: change,
        html: htmlContent,
        remoteUserId,
        remoteUserName,
        isFullUpdate,
        version: remoteVersion
      });
      return;
    }
    
    // Only filter updates that are older than the initial version we received on join
    // This prevents applying updates that were already included in the initial state
    // But we allow updates that are newer or equal to initial version (they are new changes)
    if (initialVersion !== null && remoteVersion !== null && remoteVersion < initialVersion) {
      console.log('[Editor] Ignoring outdated remote update from', remoteUserId, 'version:', remoteVersion, 'initial:', initialVersion);
      return;
    }

    // Validate change data
    if (!change || (!change.content && !Array.isArray(change))) {
      console.warn('[Editor] Invalid remote update received:', change);
      return;
    }

    const updatedPending = [];
    let remoteDelta = new Delta(change.content || change);

    // Validate delta has operations
    if (!remoteDelta.ops || remoteDelta.ops.length === 0) {
      console.log('[Editor] Ignoring empty remote delta from', remoteUserId);
      return;
    }

    // Transform the remote delta against all pending local changes
    // This ensures correct ordering when multiple users edit simultaneously
    for (const pendingDelta of pendingChanges) {
        const transformedRemote = Delta.transform(remoteDelta, pendingDelta, false);
        const transformedPending = Delta.transform(pendingDelta, remoteDelta, true);
        remoteDelta = transformedRemote;
        updatedPending.push(transformedPending);
    }

    if (updatedPending.length > 0) {
      pendingChanges = updatedPending;
    }

    // Queue the transformed remote change for application
    pendingRemoteChanges.push({
      change: { content: remoteDelta.toJSON() },
      html: htmlContent,
      remoteUserId,
      remoteUserName,
      isFullUpdate,
      version: remoteVersion
    });
    
    // Process changes sequentially to maintain document consistency
    if (!processingRemoteChanges) {
      processRemoteChanges();
    }
  }

  function processRemoteChanges() {
    // Don't process during initialization
    if (isInitializing) {
      console.log('[Editor] Deferring remote changes processing until initialization completes');
      processingRemoteChanges = false;
      return;
    }

    if (pendingRemoteChanges.length === 0) {
      processingRemoteChanges = false;
      return;
    }

    processingRemoteChanges = true;
    
    // Take the next change from the queue
    const { change, html, isFullUpdate, remoteUserId, version } = pendingRemoteChanges.shift();

    // Double-check we're not processing during initialization
    if (isInitializing) {
      console.log('[Editor] Skipping remote change from', remoteUserId, 'during initialization');
      processingRemoteChanges = false;
      // Re-queue the change for later
      pendingRemoteChanges.unshift({ change, html, isFullUpdate, remoteUserId, version });
      return;
    }
    
    // Filter out updates that are older than the initial version we received on join
    // This prevents applying updates that were already included in the initial state
    // But we allow updates that are newer or equal to initial version (they are new changes)
    if (initialVersion !== null && version !== null && version < initialVersion) {
      console.log('[Editor] Filtering outdated update from', remoteUserId, 'version:', version, 'initial:', initialVersion);
      // Process next change
      if (pendingRemoteChanges.length > 0) {
        requestAnimationFrame(processRemoteChanges);
      } else {
        processingRemoteChanges = false;
      }
      return;
    }

    isApplyingRemoteChange = true;
    try {
      // Update client version to match the remote version after applying the change
      // This ensures we stay in sync with the server
      if (version !== null && collaborativeClient && (collaborativeClient.version === undefined || version > collaborativeClient.version)) {
        collaborativeClient.version = version;
      }
      
      const { from, to } = editor.state.selection;
      const cursorPosition = { from, to };
      
      // Priority: HTML snapshot > Delta > Full update delta
      // HTML is the source of truth when available (complete snapshot)
      if (typeof html === 'string' && html.length > 0) {
        const currentHtml = editor.getHTML();
        // Only apply if HTML is different to avoid unnecessary updates
        if (currentHtml !== html) {
          editor.commands.setContent(html, false, { emitUpdate: false });
        }
        // Don't apply delta if we used HTML - HTML is already complete
      } else if (change && change.content && Array.isArray(change.content) && change.content.length > 0) {
        // Apply delta only if no HTML was provided
        const delta = new Delta(change.content);
        
        // Validate delta has meaningful operations (not just retains)
        const hasChanges = delta.ops.some(op => op.insert || op.delete);
        
        if (hasChanges) {
          if (isFullUpdate) {
            // For full updates, clear first then apply delta
            editor.commands.setContent('', false, { emitUpdate: false });
            Delta.applyToTiptap(editor, delta);
          } else {
            // For incremental updates, just apply the delta
            Delta.applyToTiptap(editor, delta);
          }
        }
      }
      
      // Adjust cursor position based on the change that was actually applied
      const delta = change && change.content ? new Delta(change.content) : new Delta([]);
      const adjustedPosition = adjustCursorPosition(delta, cursorPosition);
      
      requestAnimationFrame(() => {
        if (editor && !editor.isDestroyed) {
          try {
            // Only adjust selection if the editor doesn't have focus.
            // If it has focus, the user is typing, and we don't want to move their cursor.
            if (!editor.isFocused) {
              editor.commands.setTextSelection({ 
                from: Math.max(1, adjustedPosition.from), 
                to: Math.max(1, adjustedPosition.to) 
              });
            }
          } catch (e) {
            // Ignore errors: can happen if selection is out of bounds during rapid changes
            console.warn('[Editor] Error adjusting cursor position:', e);
          }
        }
      });
    } catch (error) {
      console.error(intl.errorApplyingUpdate, error, 'from user:', remoteUserId);
    } finally {
      isApplyingRemoteChange = false;
      
      // If there are more changes, process them in the next animation frame
      // to avoid blocking the main thread and allow UI to update.
      if (pendingRemoteChanges.length > 0 && !isInitializing) {
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
    if (!enableCollaboration) return null;

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
      
      // Synchronize version immediately after connection
      if (collaborativeClient && response.version !== undefined) {
        collaborativeClient.version = response.version;
        initialVersion = response.version; // Store initial version for filtering outdated updates
      }

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
        // Ignore updates during initialization or when applying remote changes
        if (isInitializing || isRemote || isApplyingRemoteChange || (collaborativeClient && collaborativeClient.isApplyingRemoteChange)) return;

        const newContent = editor.getHTML();
        
        // Save to database via LiveView
        debounceUpdate(newContent);

        // Only send changes if collaboration is enabled, connected, and initialization is complete
        if (collaborativeClient && isConnected && !isInitializing && transaction.docChanged) {
          try {
            // Use transaction.before (document before changes) to correctly calculate delta
            // This ensures we only capture incremental changes, not the full document state
            const beforeDoc = transaction.before;
            const delta = Delta.fromTiptapTransaction(beforeDoc, transaction);
            const ops = delta.toJSON();
            
            // Only send non-empty deltas (ignore pure retain operations)
            const hasChanges = ops.some(op => op.insert || op.delete);
            
            if (hasChanges) {
              // Validate version is synchronized before sending
              if (collaborativeClient.version === undefined || collaborativeClient.version === null) {
                console.warn('[Editor] Version not synchronized, skipping change send');
                return;
              }
              
              pendingChanges.push(delta);
              collaborativeClient.sendChange({ type: 'delta', content: ops }, newContent, (response) => {
                // Update version on successful ack
                if (response && response.version !== undefined) {
                  collaborativeClient.version = response.version;
                }
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

    // Priority: Delta > HTML > Fallback content
    // Delta is the source of truth for collaborative documents
    // Apply initial content only once, ensuring editor is ready
    if (!initialContentApplied) {
      initialContentApplied = true;
      
      // Check if editor already has content (fast reload scenario)
      const currentContent = editor.getHTML();
      const hasExistingContent = currentContent && currentContent.trim().length > 0 && 
                                 currentContent !== '<p></p>' && 
                                 currentContent !== '<p><br></p>';
      
      // Use requestAnimationFrame to ensure editor is fully initialized
      requestAnimationFrame(() => {
        // Only apply initial content if editor is empty or has minimal content
        if (!hasExistingContent) {
          if (initialContents && Array.isArray(initialContents) && initialContents.length > 0) {
            // Use delta - it represents the complete document state
            // The delta contains the full document, so we apply it to an empty editor
            const delta = new Delta(initialContents);
            
            // Validate delta has content before applying
            const hasContent = delta.ops.some(op => op.insert);
            
            if (hasContent) {
              // For initial content, use HTML if available (more reliable for initial load)
              // Otherwise, apply delta directly without normalization
              if (initialHtml && typeof initialHtml === 'string' && initialHtml.length > 0) {
                // Use HTML for initial content - it's more reliable
                editor.commands.setContent(initialHtml, false, { emitUpdate: false });
                
                setTimeout(() => {
                  isInitializing = false;
                  console.log('[Editor] Initialization complete (HTML), version:', collaborativeClient?.version);
                  
                  if (pendingRemoteChanges.length > 0) {
                    console.log('[Editor] Processing', pendingRemoteChanges.length, 'queued remote updates');
                    processRemoteChanges();
                  }
                }, 350);
              } else {
                // Apply delta directly - but ensure editor is properly cleared first
                // Clear editor completely before applying delta
                editor.commands.clearContent({ emitUpdate: false });
                
                // Wait for editor to be cleared, then apply delta
                requestAnimationFrame(() => {
                  // Double-check editor is empty (should be size 1 for minimal paragraph)
                  const docSize = editor.state.doc.content.size;
                  
                  if (docSize > 1) {
                    // Editor still has content, clear again and wait
                    editor.commands.clearContent({ emitUpdate: false });
                    requestAnimationFrame(() => {
                      applyInitialDelta();
                    });
                  } else {
                    applyInitialDelta();
                  }
                });
                
                function applyInitialDelta() {
                  // For initial content in empty editor, we need to handle it specially
                  // Extract all text from delta operations first
                  let allText = '';
                  const textAttributes = [];
                  
                  for (const op of delta.ops) {
                    if (op.insert && typeof op.insert === 'string') {
                      allText += op.insert;
                      if (op.attributes) {
                        textAttributes.push({ text: op.insert, attributes: op.attributes });
                      } else {
                        textAttributes.push({ text: op.insert, attributes: null });
                      }
                    }
                  }
                  
                  if (allText.length === 0) {
                    // No text to insert
                    setTimeout(() => {
                      isInitializing = false;
                    }, 100);
                    return;
                  }
                  
                  // Create a transaction to apply the delta
                  const tr = editor.state.tr;
                  tr.setMeta('isRemote', true);
                  tr.setMeta('addToHistory', false);
                  
                  // For empty editor, we insert at position 1
                  // But we need to ensure we're inserting inside the paragraph, not after it
                  const docSize = tr.doc.content.size;
                  
                  if (docSize === 1) {
                    // Editor is empty (just the minimal paragraph structure)
                    // Insert text at position 1 (inside the paragraph)
                    // If we have attributes, apply them
                    if (textAttributes.length === 1 && textAttributes[0].attributes) {
                      // Single text with attributes
                      const marks = [];
                      Object.entries(textAttributes[0].attributes).forEach(([key, value]) => {
                        const markType = editor.schema.marks[key];
                        if (markType && value) {
                          marks.push(markType.create());
                        }
                      });
                      tr.insertText(textAttributes[0].text, 1, marks);
                    } else {
                      // Multiple text segments or no attributes - insert all at once
                      // For simplicity, insert all text and then apply marks if needed
                      tr.insertText(allText, 1);
                      
                      // Apply marks if we have attributes
                      if (textAttributes.length > 0 && textAttributes[0].attributes) {
                        let currentPos = 1;
                        for (const { text, attributes } of textAttributes) {
                          if (attributes) {
                            const marks = [];
                            Object.entries(attributes).forEach(([key, value]) => {
                              const markType = editor.schema.marks[key];
                              if (markType && value) {
                                marks.push(markType.create());
                              }
                            });
                            if (marks.length > 0) {
                              tr.addMark(currentPos, currentPos + text.length, marks);
                            }
                          }
                          currentPos += text.length;
                        }
                      }
                    }
                  } else {
                    // Editor has content, use standard delta application
                    let index = 1;
                    
                    for (const op of delta.ops) {
                      if (op.retain !== undefined) {
                        if (op.attributes) {
                          const from = index;
                          const to = index + op.retain;
                          const currentDocSize = tr.doc.content.size;
                          
                          if (from <= currentDocSize && to > from) {
                            const marks = [];
                            Object.entries(op.attributes).forEach(([key, value]) => {
                              const markType = editor.schema.marks[key];
                              if (markType && value) {
                                marks.push(markType.create());
                              }
                            });
                            if (marks.length > 0) {
                              tr.addMark(from, Math.min(to, currentDocSize), marks);
                            }
                          }
                        }
                        index += op.retain;
                      } else if (op.insert !== undefined) {
                        const text = op.insert;
                        if (text && typeof text === 'string') {
                          const marks = [];
                          if (op.attributes) {
                            Object.entries(op.attributes).forEach(([key, value]) => {
                              const markType = editor.schema.marks[key];
                              if (markType && value) {
                                marks.push(markType.create());
                              }
                            });
                          }
                          const insertPos = Math.max(1, Math.min(index, tr.doc.content.size));
                          tr.insertText(text, insertPos, marks);
                          index += text.length;
                        }
                      } else if (op.delete !== undefined) {
                        const from = index;
                        const to = index + op.delete;
                        const currentDocSize = tr.doc.content.size;
                        
                        if (from < currentDocSize && to > from) {
                          tr.delete(from, Math.min(to, currentDocSize));
                        }
                      }
                    }
                  }
                  
                  // Dispatch the transaction
                  if (tr.docChanged) {
                    editor.view.dispatch(tr);
                  }
                  
                  // Mark initialization complete
                  setTimeout(() => {
                    isInitializing = false;
                    const finalContent = editor.getHTML();
                    console.log('[Editor] Initialization complete (delta), version:', collaborativeClient?.version, 
                      'delta ops:', delta.ops.length, 'text length:', allText.length, 
                      'final content preview:', finalContent.substring(0, 100));
                    
                    if (pendingRemoteChanges.length > 0) {
                      console.log('[Editor] Processing', pendingRemoteChanges.length, 'queued remote updates');
                      processRemoteChanges();
                    }
                  }, 350);
                }
              }
            } else {
              // Empty delta, mark as initialized
              setTimeout(() => {
                isInitializing = false;
                console.log('[Editor] Initialization complete (empty delta), version:', collaborativeClient?.version);
              }, 100);
            }
          } else if (initialHtml && typeof initialHtml === 'string' && initialHtml.length > 0) {
            // Fallback to HTML if no delta available
            editor.commands.setContent(initialHtml, true, { emitUpdate: false });
            setTimeout(() => {
              isInitializing = false;
              console.log('[Editor] Initialization complete (HTML), version:', collaborativeClient?.version);
              
              // Process any queued remote updates
              if (pendingRemoteChanges.length > 0) {
                processRemoteChanges();
              }
            }, 350);
          } else if (content && typeof content === 'string' && content.length > 0) {
            // Final fallback to prop content
            editor.commands.setContent(content, true, { emitUpdate: false });
            setTimeout(() => {
              isInitializing = false;
              console.log('[Editor] Initialization complete (fallback), version:', collaborativeClient?.version);
            }, 300);
          } else {
            // No initial content, mark as initialized immediately
            setTimeout(() => {
              isInitializing = false;
              console.log('[Editor] Initialization complete (empty), version:', collaborativeClient?.version);
            }, 100);
          }
        } else {
          // Editor already has content, skip applying initial state
          // This prevents duplication on fast reloads
          console.log('[Editor] Editor already has content, skipping initial state application');
          setTimeout(() => {
            isInitializing = false;
            console.log('[Editor] Initialization complete (existing content), version:', collaborativeClient?.version);
            
            // Process any queued remote updates
            if (pendingRemoteChanges.length > 0) {
              processRemoteChanges();
            }
          }, 100);
        }
      });
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