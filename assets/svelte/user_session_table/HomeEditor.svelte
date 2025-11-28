<script>
  import { onMount, onDestroy, tick } from 'svelte'
  import { writable } from 'svelte/store'
  import { Motion } from 'svelte-motion'
  import { Editor } from '@tiptap/core'
  import StarterKit from '@tiptap/starter-kit'
  import Placeholder from '@tiptap/extension-placeholder'
  import FontFamily from '@tiptap/extension-font-family'
  import { TextStyle } from '@tiptap/extension-text-style'
  import Color from '@tiptap/extension-color'

  export let live = null

  // State management with stores for better reactivity
  const editorState = writable({
    note: '',
    isExpanded: false,
    isClosing: false,
    isSaving: false,
    mode: 'text'
  })

  let inputEl
  let editorElement
  let editor = null

  // Reactive declarations
  $: ({ note, isExpanded, isClosing, isSaving, mode } = $editorState)

  const menuItems = [
    {
      label: 'H1',
      active: () => ['heading', { level: 1 }],
      command: () => editor?.chain().focus().toggleHeading({ level: 1 }).run(),
    },
    {
      label: 'H2',
      active: () => ['heading', { level: 2 }],
      command: () => editor?.chain().focus().toggleHeading({ level: 2 }).run(),
    },
    {
      label: 'H3',
      active: () => ['heading', { level: 3 }],
      command: () => editor?.chain().focus().toggleHeading({ level: 3 }).run(),
    },
    {
      label: '<strong>B</strong>',
      active: () => ['bold'],
      command: () => editor?.chain().focus().toggleBold().run(),
    },
    {
      label: '<em>I</em>',
      active: () => ['italic'],
      command: () => editor?.chain().focus().toggleItalic().run(),
    },
  ]

  const springConfig = {
    type: 'spring',
    stiffness: 300,
    damping: 30,
    mass: 1,
  }

  const tweenConfig = {
    type: 'tween',
    duration: 0.3,
    ease: [0.4, 0, 0.2, 1],
  }

  /**
   * Initialize TipTap editor asynchronously
   * Uses tick() to ensure DOM is ready
   */
  async function initEditor() {
    if (!editorElement) return

    // Wait for DOM to be fully updated
    await tick()

    const extensions = [
      StarterKit,
      TextStyle,
      Color.configure({ types: ['textStyle'] }),
      FontFamily,
      Placeholder.configure({
        placeholder: 'Start typing your note...',
      }),
    ]

    editor = new Editor({
      element: editorElement,
      extensions,
      editorProps: {
        attributes: {
          class:
            'prose prose-lg max-w-none w-full px-4 py-6 focus:outline-none min-h-[300px]',
        },
      },
      content: note ? `<p>${note}</p>` : '',
      autofocus: 'end',
    })
  }

  /**
   * Handle input focus - expand editor
   */
  async function handleInputFocus() {
    if (isExpanded) return
    
    editorState.update(state => ({ ...state, isExpanded: true }))
    
    // Wait for DOM update, then initialize editor
    await tick()
    await initEditor()
  }

  function handleClose() {
    editorState.update(state => ({ 
      ...state, 
      isClosing: true,
      isSaving: false 
    }))
  }

  /**
   * Called when closing animation completes
   */
  function onCloseComplete() {
    editor?.destroy()
    editor = null
    
    editorState.set({
      note: '',
      isExpanded: false,
      isClosing: false,
      isSaving: false,
      mode: 'text'
    })
  }

  /**
   * Validate and save content
   */
  async function handleSaveAndOpen() {
    if (!editor || isSaving) return

    const content = editor.getHTML()
    
    // Validate content
    if (!content || !content.trim() || content === '<p></p>' || content === '<p><br></p>') {
      return
    }
    
    // Check content size (max 1MB)
    if (content.length > 1_000_000) {
      console.error('[HomeEditor] Content too large')
      return
    }

    if (!live) {
      console.error('[HomeEditor] LiveView connection not available')
      return
    }

    try {
      editorState.update(state => ({ ...state, isSaving: true }))
      
      live.pushEvent('create_session_with_content', {
        content: content,
        mode: mode,
      })
    } catch (error) {
      console.error('[HomeEditor] Failed to create session:', error)
      editorState.update(state => ({ ...state, isSaving: false }))
    }
  }

  /**
   * Open drawing mode
   */
  async function handleDrawModeOpen() {
    if (isSaving) return

    if (!live) {
      console.error('[HomeEditor] LiveView connection not available')
      return
    }

    try {
      editorState.update(state => ({ ...state, isSaving: true }))
      
      live.pushEvent('create_session_with_content', {
        content: '',
        mode: 'drawing',
      })
    } catch (error) {
      console.error('[HomeEditor] Failed to create drawing session:', error)
      editorState.update(state => ({ ...state, isSaving: false }))
    }
  }

  /**
   * Global keyboard shortcuts
   */
  function handleKeydown(e) {
    if (e.key === 'Escape' && isExpanded) {
      handleClose()
    }

    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
      e.preventDefault()
      if (!isExpanded) {
        inputEl?.focus()
      }
    }

    if ((e.ctrlKey || e.metaKey) && e.key === 'Enter' && isExpanded) {
      if (mode === 'text') {
        handleSaveAndOpen()
      } else {
        handleDrawModeOpen()
      }
    }
  }

  onMount(() => {
    window.addEventListener('keydown', handleKeydown)
    return () => window.removeEventListener('keydown', handleKeydown)
  })

  onDestroy(() => {
    if (editor) {
      editor.destroy()
    }
  })
</script>

<Motion
  initial={{ opacity: 0 }}
  animate={{ opacity: 1 }}
  transition={tweenConfig}
  let:motion
>
  <div use:motion class="w-full px-4">
    <div class="flex justify-center items-center py-4">
      {#if !isExpanded}
        <!-- Collapsed Input State -->
        <Motion
          initial={{ scale: 1 }}
          animate={{ scale: isExpanded ? 0.95 : 1 }}
          transition={springConfig}
          let:motion
        >
          <div use:motion class="join w-full max-w-2xl">
            <div class="relative join-item flex-1">
              <input
                type="text"
                placeholder="What about today?"
                class="input input-bordered join-item w-full bg-base-200 text-base-content border-base-300"
                bind:value={$editorState.note}
                bind:this={inputEl}
                on:focus={handleInputFocus}
                on:keydown={handleKeydown}
              />
              <kbd
                class="kbd kbd-xs absolute right-7 top-1/2 -translate-y-1/2 opacity-40"
                >⌘</kbd
              >
              <kbd
                class="kbd kbd-xs absolute right-2 top-1/2 -translate-y-1/2 opacity-40"
                >k</kbd
              >
            </div>
            <button
              class="btn btn-square join-item bg-base-200 text-base-content border-y border-base-300 border-r hover:bg-primary hover:text-primary-content transition-colors"
              on:click={handleInputFocus}
              title="Create drawing note"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="18"
                height="18"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path
                  d="M3 15c2 3 4 4 7 4s7-3 7-7-3-7-6-7-5 1.5-5 4 2 5 6 5 8.408-2.453 10-5"
                />
              </svg>
            </button>
          </div>
        </Motion>
      {:else}
        <!-- Expanded Editor State -->
        <Motion
          initial={{ opacity: 0, y: -10, scaleY: 0.8 }}
          animate={{
            opacity: isClosing ? 0 : 1,
            y: isClosing ? 20 : 0,
            scaleY: isClosing ? 0.1 : 1,
          }}
          transition={springConfig}
          onAnimationComplete={() => {
            if (isClosing) {
              onCloseComplete()
            }
          }}
          let:motion
        >
          <div use:motion class="w-full max-w-6xl origin-top">
            <div
              class="bg-base-100 rounded-lg shadow-2xl flex flex-col border border-base-300 overflow-hidden"
            >
              <!-- Toolbar -->
              {#if mode === 'text' && editor}
                <Motion
                  initial={{ opacity: 0, y: -10 }}
                  animate={{
                    opacity: isClosing ? 0 : 1,
                    y: isClosing ? -10 : 0,
                  }}
                  transition={{ ...tweenConfig, delay: isClosing ? 0.2 : 0.15 }}
                  let:motion
                >
                  <div
                    use:motion
                    class="p-3 bg-base-100 border-b border-base-300"
                  >
                    <div class="flex items-center gap-2 flex-wrap">
                      {#each menuItems as item}
                        {@const activeArgs = item.active()}
                        {@const isActive = Array.isArray(activeArgs)
                          ? editor.isActive(...activeArgs)
                          : false}
                        <button
                          type="button"
                          on:click={() => item.command()}
                          class="btn btn-sm {isActive
                            ? 'btn-neutral'
                            : 'btn-ghost'} transition-all duration-200"
                          title={item.label}
                        >
                          {@html item.label}
                        </button>
                      {/each}
                    </div>
                  </div>
                </Motion>
              {/if}

              <!-- Content -->
              <Motion
                initial={{ opacity: 0 }}
                animate={{ opacity: isClosing ? 0 : 1 }}
                transition={{ ...tweenConfig, delay: isClosing ? 0.15 : 0.2 }}
                let:motion
              >
                <div use:motion class="flex-1 p-6 bg-base-200">
                  {#if mode === 'text'}
                    <div bind:this={editorElement} class="w-full" />
                  {:else}
                    <div class="max-w-4xl mx-auto">
                      <div class="alert alert-info">
                        <svg
                          xmlns="http://www.w3.org/2000/svg"
                          fill="none"
                          viewBox="0 0 24 24"
                          class="stroke-current shrink-0 w-6 h-6"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                          />
                        </svg>
                        <span
                          >Drawing mode will open in the full editor. Click
                          "Open Drawing" to start.</span
                        >
                      </div>
                    </div>
                  {/if}
                </div>
              </Motion>

              <!-- Footer -->
              <Motion
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: isClosing ? 0 : 1, y: isClosing ? 10 : 0 }}
                transition={{ ...tweenConfig, delay: isClosing ? 0.1 : 0.25 }}
                let:motion
              >
                <div
                  use:motion
                  class="flex items-center justify-between p-4 border-t border-base-300 bg-base-200"
                >
                  <div class="text-sm text-base-content/60">
                    {#if mode === 'text'}
                      <kbd class="kbd kbd-sm">⌘</kbd> +
                      <kbd class="kbd kbd-sm">Enter</kbd> to save and open
                    {/if}
                  </div>

                  <div class="flex gap-2">
                    <button
                      class="btn btn-ghost"
                      on:click={handleClose}
                      disabled={isSaving}
                    >
                      Cancel
                    </button>
                    <button
                      class="btn btn-primary gap-2"
                      on:click={mode === 'text'
                        ? handleSaveAndOpen
                        : handleDrawModeOpen}
                      disabled={isSaving}
                    >
                      {#if isSaving}
                        <span class="loading loading-spinner loading-sm"></span>
                        Opening...
                      {:else}
                        <svg
                          xmlns="http://www.w3.org/2000/svg"
                          width="18"
                          height="18"
                          viewBox="0 0 24 24"
                          fill="none"
                          stroke="currentColor"
                          stroke-width="2"
                          stroke-linecap="round"
                          stroke-linejoin="round"
                        >
                          <path d="M15 3h6v6M9 21H3v-6M21 3l-7 7M3 21l7-7" />
                        </svg>
                        {mode === 'text' ? 'Open Note' : 'Open Drawing'}
                      {/if}
                    </button>
                  </div>
                </div>
              </Motion>
            </div>
          </div>
        </Motion>
      {/if}
    </div>
  </div>
</Motion>

<style>
  :global(.ProseMirror) {
    outline: none;
    min-height: 300px;
    color: var(--bc);
  }

  :global(.prose) {
    max-width: 100% !important;
  }

  :global(.prose .tiptap-placeholder::before) {
    content: attr(data-placeholder);
    float: left;
    color: #9ca3af;
    pointer-events: none;
    height: 0;
  }
</style>
