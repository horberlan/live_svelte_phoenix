<script>
  import BubbleMenuComponent from './menus_editor/BubbleMenu.svelte'
  import BackgroundSelector from './menus_editor/BackgroundSelector.svelte'
  import TextColorSelector from './menus_editor/TextColorSelector.svelte'
  import { onMount, onDestroy } from 'svelte'
  import { Editor } from '@tiptap/core'
  import BubbleMenu from '@tiptap/extension-bubble-menu'
  import StarterKit from '@tiptap/starter-kit'
  import Placeholder from '@tiptap/extension-placeholder'
  import FontFamily from '@tiptap/extension-font-family'
  import { TextStyle } from '@tiptap/extension-text-style'
  import Color from '@tiptap/extension-color'
  import Collaboration from '@tiptap/extension-collaboration'
  import CollaborationCursor from '@tiptap/extension-collaboration-cursor'
  import * as Y from 'yjs'
  import { YjsChannelProvider } from '../js/yjs_channel_provider.js'

  export let content = ''
  export let live = null
  export let docId = 'default-doc'
  export let userId = ''
  export let userName = ''
  export let enableCollaboration = true
  export let backgroundColor = null

  let element
  let editor
  let bubbleMenu
  let ydoc
  let provider
  let toolbarUpdate = 0 // Force toolbar update

  let editorBackgroundColor = backgroundColor
  
  // Function to update toolbar
  function updateToolbar() {
    toolbarUpdate++
  }

  const intl = {
    placeholder: 'Start typing...',
  }

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
      class: 'font-thin',
    },
    {
      label: '<strong>B</strong>',
      active: () => ['bold'],
      command: () => editor.chain().focus().toggleBold().run(),
      class: 'font-bold',
    },
    {
      label: '<em>I</em>',
      active: () => ['italic'],
      class: 'italic',
      command: () => editor.chain().focus().toggleItalic().run(),
    },
  ]

  function getContrastTextColor(bg) {
    if (!bg) return 'var(--bc)'

    const div = document.createElement('div')
    div.style.color = bg
    document.body.appendChild(div)
    const rgb = getComputedStyle(div).color
    document.body.removeChild(div)

    const match = rgb.match(/\d+/g)
    if (!match) return 'black'
    const [r, g, b] = match.map(Number)

    // YIQ formula for contrast
    const yiq = (r * 299 + g * 587 + b * 114) / 1000
    return yiq >= 128 ? '#000000' : '#FFFFFF'
  }

  function applyBackgroundColor(color) {
    console.log('[Editor] Applying background color:', color)
    console.log('[Editor] Editor exists:', !!editor)
    console.log('[Editor] Editor.view exists:', !!editor?.view)
    console.log('[Editor] Editor.view.dom exists:', !!editor?.view?.dom)
    
    editorBackgroundColor = color
    if (editor && editor.view && editor.view.dom) {
      // Always set the background color on the editor DOM
      editor.view.dom.style.backgroundColor = color || ''
      console.log('[Editor] Applied backgroundColor to editor.view.dom:', editor.view.dom.style.backgroundColor)
      
      // Apply contrast text color
      if (color) {
        const textColor = getContrastTextColor(color)
        editor.view.dom.style.color = textColor
        console.log('[Editor] Applied text color:', textColor)
      } else {
        // Reset to default text color
        editor.view.dom.style.color = ''
        console.log('[Editor] Reset text color to default')
      }
    } else {
      console.warn('[Editor] Cannot apply color - editor not ready')
    }
  }

  function handleBackgroundSelected(event) {
    const { value } = event.detail || event
    console.log('[Editor] Background color selected:', value)
    applyBackgroundColor(value)
    
    // Save to server
    if (live && enableCollaboration) {
      console.log('[Editor] Sending background_color_changed to server')
      live.pushEvent('background_color_changed', { color: value })
    } else {
      console.warn('[Editor] Cannot save color - live or enableCollaboration not available', {
        live: !!live,
        enableCollaboration
      })
    }
  }

  onMount(() => {
    console.log('Editor mounting with:', { enableCollaboration, live: !!live, docId, userId, userName })
    
    const extensions = [
      StarterKit.configure({
        // The Collaboration extension comes with its own history handling
        history: false,
      }),
      TextStyle,
      Color.configure({
        types: ['textStyle'],
      }),
      FontFamily,
      Placeholder.configure({
        placeholder: intl.placeholder,
      }),
    ]
    
    if (bubbleMenu) {
      extensions.push(
        BubbleMenu.configure({
          element: bubbleMenu,
          tippyOptions: {
            duration: 100,
            placement: 'top',
            maxWidth: 'none',
            appendTo: () => document.body,
            interactive: true,
            zIndex: 1000,
            offset: [0, 10],
          },
        })
      )
    }

    if (enableCollaboration && live) {
      console.log('Setting up collaboration with Phoenix Channels...')
      ydoc = new Y.Doc()
      
      // Create provider using Phoenix Channels (more reliable than push_event)
      provider = new YjsChannelProvider(docId, ydoc, {
        userId,
        userName,
        onStatus: (status) => {
          console.log('Provider status:', status)
        },
      })

      console.log('Provider created, awareness:', provider.awareness)

      extensions.push(
        Collaboration.configure({
          document: ydoc,
        })
      )
      
      try {
        if (provider && provider.awareness) {
          console.log('Adding CollaborationCursor extension')
          extensions.push(
            CollaborationCursor.configure({
              provider: provider,
              user: {
                name: userName,
                color: '#f783ac',
              },
            })
          )
        } else {
          console.error('Awareness not available!', { provider, awareness: provider?.awareness })
        }
      } catch (error) {
        console.error('Error setting up CollaborationCursor:', error)
      }
    } else {
      console.log('Collaboration disabled or live not available')
    }

    editor = new Editor({
      element: element,
      extensions: extensions,
      editorProps: {
        attributes: {
          class:
            'prose prose-lg max-w-none w-full mx-auto px-4 sm:px-6 md:px-8 py-6 focus:outline-none shadow-md rounded-lg min-h-[600px]',
        },
      },
      content: enableCollaboration ? '' : content,
      onCreate: ({ editor }) => {
        console.log('[Editor] Editor created')
        
        editor.on('selectionUpdate', updateToolbar)
        editor.on('transaction', updateToolbar)
        
        if (enableCollaboration) {
          editor.on('update', ({ editor }) => {
            const htmlContent = editor.getHTML()
            if (htmlContent.includes('Ã') || htmlContent.includes('ð')) {
              console.warn('[Editor] ⚠️ Detected encoding issues in editor content:', htmlContent.slice(0, 200))
            }
          })
        }
      },
    })

    if (editor.view && editor.view.dom) {
      if (editorBackgroundColor) {
        applyBackgroundColor(editorBackgroundColor)
      } else {
        const testDiv = document.createElement('div')
        testDiv.className = 'bg-base-200'
        testDiv.style.display = 'none'
        document.body.appendChild(testDiv)
        const defaultColor = getComputedStyle(testDiv).backgroundColor || '#F5F5F5'
        document.body.removeChild(testDiv)
        applyBackgroundColor(defaultColor)
      }
    }

    if (live && enableCollaboration) {
      live.handleEvent('background_color_updated', (data) => {
        console.log('[Editor] Received background_color_updated:', data.color)
        applyBackgroundColor(data.color)
      })
    }

    if (!enableCollaboration) {
      let updateTimeout
      editor.on('update', ({ editor }) => {
        clearTimeout(updateTimeout)
        updateTimeout = setTimeout(() => {
          live.pushEvent('content_updated', {
            content: editor.getHTML(),
            backgroundColor: editorBackgroundColor,
          })
        }, 300)
      })

      live.handleEvent('remote_content_updated', (data) => {
        if (editor && data.content !== editor.getHTML()) {
          const { from, to } = editor.state.selection
          editor.commands.setContent(data.content, false)
          if (data.backgroundColor) {
            editorBackgroundColor = data.backgroundColor
            if (editor.view && editor.view.dom) {
              editor.view.dom.style.backgroundColor = data.backgroundColor
            }
          }
          requestAnimationFrame(() => {
            if (editor && !editor.isDestroyed) {
              editor.commands.setTextSelection({ from, to })
            }
          })
        }
      })
    }
    
    const handleBeforeUnload = () => {
      console.log('[Editor] Page unloading, cleaning up...')
      if (provider) {
        provider.destroy()
      }
    }
    
    window.addEventListener('beforeunload', handleBeforeUnload)
    
    return () => {
      window.removeEventListener('beforeunload', handleBeforeUnload)
    }
  })

  onDestroy(() => {
    console.log('[Editor] Component destroying, cleaning up...')
    
    if (provider) {
      provider.destroy()
    }
    if (editor) {
      editor.destroy()
    }
  })
</script>

<div class="relative mb-4 w-full max-w-7xl mx-auto">
  {#if editor}
    {#key toolbarUpdate}
      <div class="toolbar-fixed mb-4 p-3 bg-base-100 rounded-lg shadow-md border border-base-300">
        <div class="flex items-center gap-2 flex-wrap">
          {#each bubbleMenuItems as item, index}
            {@const activeArgs = item.active()}
            {@const isActive = Array.isArray(activeArgs) ? editor.isActive(...activeArgs) : false}
            <button
              type="button"
              on:click={() => {
                item.command()
                setTimeout(updateToolbar, 10)
              }}
              class="btn btn-sm {isActive ? 'btn-neutral' : 'btn-ghost'} transition-all duration-200"
              title={item.label}
            >
              {@html item.label}
            </button>
          {/each}
          <div class="divider divider-horizontal mx-1" />
          <TextColorSelector {editor} />
          <BackgroundSelector
            {editor}
            on:backgroundSelected={handleBackgroundSelected}
          />
        </div>
      </div>
    {/key}
  {/if}

  {#if bubbleMenuItems.length > 0}
    <div bind:this={bubbleMenu} class="bubble-menu-floating">
      <BubbleMenuComponent
        {editor}
        {bubbleMenuItems}
        on:backgroundSelected={handleBackgroundSelected}
      />
    </div>
  {/if}
  
  <div
    bind:this={element}
    class="w-full editor-bg-animated transition-colors duration-300"
  />
</div>

<style>
  :global(.editor-bg-animated) {
    transition: background-color 0.3s ease-in-out;
  }
  
  .toolbar-fixed {
    position: sticky;
    top: 0;
    z-index: 10;
  }
  
  :global(.bubble-menu-floating) {
    visibility: hidden;
    pointer-events: none;
  }
  
  :global(.bubble-menu-floating.is-active) {
    visibility: visible;
    pointer-events: auto;
  }
  
  :global(.prose) {
    max-width: 100% !important;
  }
  
  :global(.ProseMirror) {
    color: var(--bc);
  }
  
  :global(.ProseMirror span[style*="color: #"]),
  :global(.ProseMirror span[style*="color:#"]),
  :global(.ProseMirror span[style*="color: rgb"]) {
    all: unset;
    display: inline;
  }
  
  :global(.ProseMirror span[style*="color: #000000"]),
  :global(.ProseMirror span[style*="color:#000000"]) {
    color: #000000 !important;
  }
  
  :global(.ProseMirror span[style*="color: #6B7280"]),
  :global(.ProseMirror span[style*="color:#6B7280"]) {
    color: #6B7280 !important;
  }
  
  :global(.ProseMirror span[style*="color: #EF4444"]),
  :global(.ProseMirror span[style*="color:#EF4444"]) {
    color: #EF4444 !important;
  }
  
  :global(.ProseMirror span[style*="color: #F97316"]),
  :global(.ProseMirror span[style*="color:#F97316"]) {
    color: #F97316 !important;
  }
  
  :global(.ProseMirror span[style*="color: #EAB308"]),
  :global(.ProseMirror span[style*="color:#EAB308"]) {
    color: #EAB308 !important;
  }
  
  :global(.ProseMirror span[style*="color: #22C55E"]),
  :global(.ProseMirror span[style*="color:#22C55E"]) {
    color: #22C55E !important;
  }
  
  :global(.ProseMirror span[style*="color: #14B8A6"]),
  :global(.ProseMirror span[style*="color:#14B8A6"]) {
    color: #14B8A6 !important;
  }
  
  :global(.ProseMirror span[style*="color: #3B82F6"]),
  :global(.ProseMirror span[style*="color:#3B82F6"]) {
    color: #3B82F6 !important;
  }
  
  :global(.ProseMirror span[style*="color: #A855F7"]),
  :global(.ProseMirror span[style*="color:#A855F7"]) {
    color: #A855F7 !important;
  }
  
  :global(.ProseMirror span[style*="color: #EC4899"]),
  :global(.ProseMirror span[style*="color:#EC4899"]) {
    color: #EC4899 !important;
  }
  
  :global(.prose-lg) {
    font-size: 1rem;
  }
  
  @media (min-width: 640px) {
    :global(.prose-lg) {
      font-size: 1.125rem;
    }
  }
  
  @media (min-width: 1024px) {
    :global(.prose-lg) {
      font-size: 1.25rem;
    }
  }
  
  :global(.prose .tiptap-placeholder::before) {
    content: attr(data-placeholder);
    float: left;
    color: #adb5bd;
    pointer-events: none;
    height: 0;
  }
  
  :global(.collaboration-cursor__caret) {
    position: relative;
    margin-left: -1px;
    margin-right: -1px;
    border-left: 1px solid #0d0d0d;
    border-right: 1px solid #0d0d0d;
    word-break: normal;
    pointer-events: none;
  }
  
  :global(.collaboration-cursor__label) {
    position: absolute;
    top: -1.4em;
    left: -1px;
    font-size: 12px;
    font-style: normal;
    font-weight: 600;
    line-height: normal;
    user-select: none;
    color: #0d0d0d;
    padding: 0.1rem 0.3rem;
    border-radius: 3px 3px 3px 0;
    white-space: nowrap;
  }
</style>
