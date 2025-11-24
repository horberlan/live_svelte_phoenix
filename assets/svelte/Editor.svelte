<script>
  import BubbleMenuComponent from './menus_editor/BubbleMenu.svelte'
  import { onMount, onDestroy } from 'svelte'
  import { Editor } from '@tiptap/core'
  import BubbleMenu from '@tiptap/extension-bubble-menu'
  import StarterKit from '@tiptap/starter-kit'
  import Placeholder from '@tiptap/extension-placeholder'
  import FontFamily from '@tiptap/extension-font-family'
  import { TextStyle } from '@tiptap/extension-text-style'
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

  let editorBackgroundColor = backgroundColor

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

  function handleBackgroundSelected(event) {
    const { value } = event.detail || event
    console.log('[Editor] Background color selected:', value)
    editorBackgroundColor = value
    if (editor && editor.view && editor.view.dom) {
      editor.view.dom.style.backgroundColor = editorBackgroundColor
    }
    
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
      FontFamily,
      BubbleMenu.configure({
        element: bubbleMenu,
      }),
      Placeholder.configure({
        placeholder: intl.placeholder,
      }),
    ]

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
      
      // Add CollaborationCursor - it needs the provider, not just awareness
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
            'prose max-w-none prose-sm sm:prose-base m-5 p-4 focus:outline-none shadow-md rounded-lg min-h-96',
        },
      },
      // In collaborative mode, content comes from Yjs, not from the content prop
      content: enableCollaboration ? '' : content,
    })

    // Apply initial background color
    if (editorBackgroundColor && editor.view && editor.view.dom) {
      editor.view.dom.style.backgroundColor = editorBackgroundColor
    }

    if (!enableCollaboration) {
      // Non-collaborative mode logic
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
  })

  onDestroy(() => {
    if (editor) {
      editor.destroy()
    }
    if (provider) {
      provider.destroy()
    }
  })
</script>

<div class="relative mb-4">
  <BubbleMenuComponent
    {editor}
    {bubbleMenuItems}
    on:backgroundSelected={handleBackgroundSelected}
  />
  {#if bubbleMenuItems.length > 0}
    <div
      class="flex gap-2 bg-base-100 p-2 rounded-lg shadow-sm"
      bind:this={bubbleMenu}
    />
  {/if}
  <div
    bind:this={element}
    class="w-full editor-bg-animated transition-colors duration-300"
    style="background-color: {editorBackgroundColor}"
  />
</div>

<style>
  :global(.editor-bg-animated) {
    transition: background-color 0.3s ease-in-out;
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
