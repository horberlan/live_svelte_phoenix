<script>
  import BubbleMenuComponent from './menus_editor/BubbleMenu.svelte'
  import { onMount, onDestroy } from 'svelte'
  import { Editor } from '@tiptap/core'
  import BubbleMenu from '@tiptap/extension-bubble-menu'
  import StarterKit from '@tiptap/starter-kit'

  let element
  let editor

  let bubbleMenu

  export let content
  export let live

  let bubbleMenuItems = [
    {
      label: 'H1',
      active: () => ('heading', { level: 1 }),
      command: () => editor.chain().focus().toggleHeading({ level: 1 }).run(),
    },
    {
      label: 'H2',
      active: () => ('heading', { level: 2 }),
      command: () => editor.chain().focus().toggleHeading({ level: 2 }).run(),
    },
    {
      label: 'H3',
      active: () => ('heading', { level: 3 }),
      command: () => editor.chain().focus().toggleHeading({ level: 3 }).run(),
    },
    {
      label: 'P',
      active: () => 'paragraph',
      command: () => editor.chain().focus().setParagraph().run(),
    },
    {
      label: 'Bold',
      active: () => 'bold',
      command: () => editor.chain().focus().toggleBold().run(),
    },
    {
      label: 'Italic',
      active: () => 'italic',
      command: () => editor.chain().focus().toggleItalic().run(),
    },
  ]

  onMount(() => {
    editor = new Editor({
      element: element,
      extensions: [
        StarterKit,
        BubbleMenu.configure({
          element: bubbleMenu,
        }),
      ],
      editorProps: {
        attributes: {
          class:
            'prose prose-sm sm:prose-base lg:prose-lg xl:prose-2xl m-5 focus:outline-none bg-white shadow-md p-4 rounded-lg',
        },
      },
      content,
      onTransaction: () => {
        editor = editor
      },
      onUpdate: ({ editor }) => {
        live.pushEvent('content_updated', { content: editor.getHTML() })
      },
    })
  })

  onDestroy(() => {
    if (editor) {
      editor.destroy()
    }
  })
</script>

<BubbleMenuComponent {editor} {bubbleMenuItems} />
<div
  class="flex gap-2 bg-gray-100 p-2 rounded-lg shadow-sm w-full"
  bind:this={bubbleMenu}
>
  {#if editor}
    {#each bubbleMenuItems as item}
      <button
        on:click={item.command}
        class:active={editor.isActive(item.active())}
        class="
        {editor.isActive(item.active()) ? 'bg-black text-white' : 'bg-gray-200'}
        px-2 py-1 rounded-md hover:bg-gray-300 focus:outline-none"
      >
        {item.label}
      </button>
    {/each}
  {/if}
</div>

<div bind:this={element} />
