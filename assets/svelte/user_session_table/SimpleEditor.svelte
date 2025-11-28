<script>
  import { onMount, onDestroy } from 'svelte'
  import { Motion, AnimatePresence, AnimateSharedLayout } from 'svelte-motion'
  import { Editor } from '@tiptap/core'
  import StarterKit from '@tiptap/starter-kit'
  import Placeholder from '@tiptap/extension-placeholder'
  import FontFamily from '@tiptap/extension-font-family'
  import { TextStyle } from '@tiptap/extension-text-style'
  import Color from '@tiptap/extension-color'

  export let live
  export let initialContent = ''
  export let initialMode = 'text'
  export let onClose

  let mode = initialMode
  let element
  let editor
  let isSaving = false
  let isVisible = false

  const menuItems = [
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
      label: '<strong>B</strong>',
      active: () => ['bold'],
      command: () => editor.chain().focus().toggleBold().run(),
    },
    {
      label: '<em>I</em>',
      active: () => ['italic'],
      command: () => editor.chain().focus().toggleItalic().run(),
    },
  ]

  // Spring animation config for smooth, natural motion
  const springConfig = {
    type: 'spring',
    stiffness: 300,
    damping: 30,
    mass: 1
  }

  // Tween config for opacity
  const tweenConfig = {
    type: 'tween',
    duration: 0.3,
    ease: [0.4, 0, 0.2, 1]
  }

  function handleClose() {
    isVisible = false
    setTimeout(() => {
      if (onClose) onClose()
    }, 350)
  }

  function toggleMode() {
    mode = mode === 'text' ? 'drawing' : 'text'
  }

  function generateSessionId() {
    // Generate a secure random ID similar to Elixir's :crypto.strong_rand_bytes(32) |> Base.encode32()
    const array = new Uint8Array(32)
    crypto.getRandomValues(array)
    // Convert to base32-like string
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'
    let result = ''
    for (let i = 0; i < array.length; i++) {
      result += chars[array[i] % 32]
    }
    return result
  }

  function handleSaveAndOpen() {
    if (!editor || isSaving) return
    
    const content = editor.getHTML()
    if (!content.trim() || content === '<p></p>') return
    
    isSaving = true
    
    const sessionId = generateSessionId()
    
    if (live) {
      live.pushEvent('create_session_with_content', {
        session_id: sessionId,
        content: content,
        mode: mode
      })
    }
    
    setTimeout(() => {
      window.location.href = `/session/${sessionId}`
    }, 100)
  }

  function handleDrawModeOpen() {
    isSaving = true
    
    const sessionId = generateSessionId()
    
    if (live) {
      live.pushEvent('create_session_with_content', {
        session_id: sessionId,
        content: '',
        mode: 'drawing'
      })
    }
    
    setTimeout(() => {
      window.location.href = `/session/${sessionId}?drawing=true`
    }, 100)
  }

  function handleKeydown(e) {
    if (e.key === 'Escape') {
      handleClose()
    }
    if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
      if (mode === 'text') {
        handleSaveAndOpen()
      } else {
        handleDrawModeOpen()
      }
    }
  }

  function initEditor() {
    if (mode !== 'text' || !element) return
    
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
      element: element,
      extensions: extensions,
      editorProps: {
        attributes: {
          class: 'prose prose-lg max-w-none w-full px-4 py-6 focus:outline-none min-h-[400px]',
        },
      },
      content: initialContent ? `<p>${initialContent}</p>` : '',
      autofocus: 'end',
    })
  }

  onMount(() => {
    window.addEventListener('keydown', handleKeydown)
    
    // Trigger animation after mount
    requestAnimationFrame(() => {
      isVisible = true
    })
    
    // Initialize editor after animation starts
    setTimeout(initEditor, 150)
  })

  onDestroy(() => {
    window.removeEventListener('keydown', handleKeydown)
    if (editor) {
      editor.destroy()
    }
  })
</script>

<Motion
  initial={{ opacity: 0, y: -20, scaleY: 0.8 }}
  animate={{ 
    opacity: isVisible ? 1 : 0, 
    y: isVisible ? 0 : -20,
    scaleY: isVisible ? 1 : 0.8
  }}
  transition={springConfig}
  let:motion
>
  <div
    use:motion
    class="w-full max-w-6xl mx-auto mb-6 origin-top"
  >
    <div class="bg-base-100 rounded-lg shadow-2xl flex flex-col border border-base-300 overflow-hidden">
      <!-- Header -->
      <Motion
        initial={{ opacity: 0, x: -10 }}
        animate={{ opacity: isVisible ? 1 : 0, x: isVisible ? 0 : -10 }}
        transition={{ ...tweenConfig, delay: 0.1 }}
        let:motion
      >
        <div use:motion class="flex items-center justify-between p-4 border-b border-base-300">
          <div class="flex items-center ml-auto gap-2">
            <button
              class="btn btn-sm btn-ghost gap-2"
              on:click={toggleMode}
              title={mode === 'text' ? 'Switch to drawing' : 'Switch to text'}
            >
              {#if mode === 'text'}
                <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M3 15c2 3 4 4 7 4s7-3 7-7-3-7-6-7-5 1.5-5 4 2 5 6 5 8.408-2.453 10-5"/>
                </svg>
                Draw
              {:else}
                <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M4 7V4h16v3M9 20h6M12 4v16"/>
                </svg>
                Text
              {/if}
            </button>

            <div class="divider divider-horizontal mx-0"></div>

            <button class="btn btn-sm btn-ghost" on:click={handleClose} title="Close (Esc)">
              <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M18 6 6 18M6 6l12 12"/>
              </svg>
            </button>
          </div>
        </div>
      </Motion>

      <!-- Toolbar (only for text mode)
      {#if mode === 'text' && editor}
        <Motion
          initial={{ opacity: 0, y: -10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ ...tweenConfig, delay: 0.15 }}
          let:motion
        >
          <div use:motion class="p-3 bg-base-100 border-b border-base-300">
            <div class="flex items-center gap-2 flex-wrap">
              {#each menuItems as item}
                {@const activeArgs = item.active()}
                {@const isActive = Array.isArray(activeArgs) ? editor.isActive(...activeArgs) : false}
                <button
                  type="button"
                  on:click={() => item.command()}
                  class="btn btn-sm {isActive ? 'btn-neutral' : 'btn-ghost'} transition-all duration-200"
                  title={item.label}
                >
                  {@html item.label}
                </button>
              {/each}
            </div>
          </div>
        </Motion>
        {/if}
        -->

      <!-- Content -->
      <Motion
        initial={{ opacity: 0 }}
        animate={{ opacity: isVisible ? 1 : 0 }}
        transition={{ ...tweenConfig, delay: 0.2 }}
        let:motion
      >
        <div use:motion class="flex-1 p-6 bg-base-200">
          {#if mode === 'text'}
            <div class="max-w-4xl mx-auto bg-base-100 rounded-lg shadow-md max-h-40">
              <div bind:this={element} class="w-full" />
            </div>
          {:else}
            <div class="max-w-4xl mx-auto">
              <div class="alert alert-info">
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="stroke-current shrink-0 w-6 h-6">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                </svg>
                <span>Drawing mode will open in the full editor. Click "Open Drawing" to start.</span>
              </div>
            </div>
          {/if}
        </div>
      </Motion>

      <!-- Footer -->
      <Motion
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: isVisible ? 1 : 0, y: isVisible ? 0 : 10 }}
        transition={{ ...tweenConfig, delay: 0.25 }}
        let:motion
      >
        <div use:motion class="flex items-center justify-between p-4 border-t border-base-300 bg-base-200">
          <div class="text-sm text-base-content/60">
            {#if mode === 'text'}
              <kbd class="kbd kbd-sm">⌘</kbd> + <kbd class="kbd kbd-sm">Enter</kbd> to save and open
            {/if}
          </div>
          
          <div class="flex gap-2">
            <button class="btn btn-ghost" on:click={handleClose} disabled={isSaving}>
              Cancel
            </button>
            <button
              class="btn btn-primary gap-2"
              on:click={mode === 'text' ? handleSaveAndOpen : handleDrawModeOpen}
              disabled={isSaving}
            >
              {#if isSaving}
                <span class="loading loading-spinner loading-sm"></span>
                Opening...
              {:else}
                <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M15 3h6v6M9 21H3v-6M21 3l-7 7M3 21l7-7"/>
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

<style>
  :global(.ProseMirror) {
    outline: none;
    min-height: 400px;
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
