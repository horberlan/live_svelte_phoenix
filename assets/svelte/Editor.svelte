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
  export let drawingMode = false
  export let onToggleDrawing = null

  let element
  let editor
  let bubbleMenu
  let ydoc
  let provider
  let toolbarUpdate = 0

  let editorBackgroundColor = backgroundColor
  let lastToolbarState = ''
  let toolbarTimeout = null
  
  function checkAndUpdateToolbar() {
    if (!editor) return
    
    const currentState = bubbleMenuItems
      .map(item => {
        const activeArgs = item.active()
        return Array.isArray(activeArgs) ? editor.isActive(...activeArgs) : false
      })
      .join(',')
    
    if (currentState !== lastToolbarState) {
      lastToolbarState = currentState
      toolbarUpdate++
    }
  }

  function updateToolbar() {
    if (toolbarTimeout) clearTimeout(toolbarTimeout)
    toolbarTimeout = setTimeout(checkAndUpdateToolbar, 50)
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

    const yiq = (r * 299 + g * 587 + b * 114) / 1000
    return yiq >= 128 ? '#000000' : '#FFFFFF'
  }

  function getUserThemeColor(id) {
    // Cores baseadas no tema DaisyUI (Primary, Secondary, Accent, Info, Success, Warning, Error)
    const themeVars = [
      'hsl(var(--p))', 
      'hsl(var(--s))', 
      'hsl(var(--a))', 
      'hsl(var(--in))', 
      'hsl(var(--su))', 
      'hsl(var(--wa))', 
      'hsl(var(--er))'
    ]
    let hash = 0
    const str = id || 'default'
    for (let i = 0; i < str.length; i++) {
      hash = str.charCodeAt(i) + ((hash << 5) - hash)
    }
    return themeVars[Math.abs(hash) % themeVars.length]
  }

  function applyBackgroundColor(color) {
    editorBackgroundColor = color
    if (editor && editor.view && editor.view.dom) {
      editor.view.dom.style.backgroundColor = color || ''
      
      if (color) {
        const textColor = getContrastTextColor(color)
        editor.view.dom.style.color = textColor
      } else {
        editor.view.dom.style.color = ''
      }
    }
  }

  function handleBackgroundSelected(event) {
    const { value } = event.detail || event
    applyBackgroundColor(value)
    
    if (live && enableCollaboration) {
      live.pushEvent('background_color_changed', { color: value })
    }
  }

  onMount(() => {
    const extensions = [
      StarterKit.configure({
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
    
    // Configuração do Bubble Menu
    // O Tiptap irá mover o elemento 'bubbleMenu' para dentro de uma instância Tippy
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
            zIndex: 9999, // Z-index alto para garantir visibilidade
            offset: [0, 10],
          },
        })
      )
    }

    if (enableCollaboration && live) {
      ydoc = new Y.Doc()
      
      provider = new YjsChannelProvider(docId, ydoc, {
        userId,
        userName,
        onStatus: (status) => {
          console.log('Provider status:', status)
        },
      })

      extensions.push(
        Collaboration.configure({
          document: ydoc,
        })
      )
      
      try {
        if (provider && provider.awareness) {
          extensions.push(
            CollaborationCursor.configure({
              provider: provider,
              user: {
                name: userName,
                color: getUserThemeColor(userId || userName),
              },
            })
          )
        }
      } catch (error) {
        console.error('Error setting up CollaborationCursor:', error)
      }
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
        editor.on('selectionUpdate', updateToolbar)
        editor.on('transaction', updateToolbar)
      },
    })
    
    if (editor.view && editor.view.dom) {
      if (editorBackgroundColor) {
        applyBackgroundColor(editorBackgroundColor)
      } else {
        // Fallback seguro para cor de fundo
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
    if (provider) {
      provider.destroy()
    }
    if (editor) {
      editor.destroy()
    }
  })
</script>

<div class="relative mb-4 w-full">
  {#if editor}
    {#key toolbarUpdate}
      <div class="toolbar-fixed mb-4 p-3 bg-base-100 rounded-lg shadow-md border border-base-300">
        <div class="flex items-center gap-2 flex-wrap">
          <button
            type="button"
            on:click={() => {
              if (live) {
                live.pushEvent('toggle_drawing_mode', {})
              }
            }}
            class="btn btn-sm {drawingMode ? 'btn-primary' : 'btn-ghost'} transition-all duration-200"
            title={drawingMode ? 'Switch to text mode' : 'Switch to drawing mode'}
          >
            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 15c2 3 4 4 7 4s7-3 7-7-3-7-6-7-5 1.5-5 4 2 5 6 5 8.408-2.453 10-5"/></svg>
          </button>
          <div class="divider divider-horizontal mx-1" />
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
        {drawingMode}
        {onToggleDrawing}
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
  :global(.ProseMirror) {
    position: relative;
    outline: none;
    min-height: 100%;
    color: var(--bc);
  }
  
  :global(.prose) {
    max-width: 100% !important;
  }

  :global(.ProseMirror span[style*="color"]) {
    display: inline;
  }
  
  :global(.ProseMirror span[style*="color: #000000"]),
  :global(.ProseMirror span[style*="color:#000000"]) { color: #000000 !important; }

  /* Collaboration Cursor Styles */
  :global(.collaboration-cursor__caret) {
    position: relative;
    margin-left: -1px;
    margin-right: -1px;
    border-left: 2px solid #0d0d0d;
    border-right: 2px solid #0d0d0d;
    word-break: normal;
    pointer-events: none;
  }

  :global(.collaboration-cursor__label) {
    position: absolute;
    top: -1.4em;
    left: -2px;
    font-size: 12px;
    font-weight: 700;
    line-height: normal;
    user-select: none;
    color: #fff;
    padding: 0.1rem 0.4rem;
    border-radius: 4px 4px 4px 0;
    white-space: nowrap;
    z-index: 50;
    text-shadow: 0 1px 2px rgba(0,0,0,0.2);
  }

  :global(.prose-lg) {
    font-size: 1rem;
  }
  
  @media (min-width: 640px) {
    :global(.prose-lg) { font-size: 1.125rem; }
  }
  
  @media (min-width: 1024px) {
    :global(.prose-lg) { font-size: 1.25rem; }
  }
  
  :global(.prose .tiptap-placeholder::before) {
    content: attr(data-placeholder);
    float: left;
    color: #9ca3af;
    pointer-events: none;
    height: 0;
  }

  :global(.editor-bg-animated) {
    transition: background-color 0.3s ease-in-out;
  }
  
  .toolbar-fixed {
    position: sticky;
    top: 0;
    z-index: 40;
  }
  
  :global(.bubble-menu-floating) {
    display: flex;
    z-index: 9999;
  }
</style>