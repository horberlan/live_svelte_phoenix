<script>
  import { onMount, onDestroy } from 'svelte'
  import { Editor } from '@tiptap/core'
  import StarterKit from '@tiptap/starter-kit'
  import BubbleMenuComponent from './menus_editor/BubbleMenu.svelte'
  import BubbleMenu from '@tiptap/extension-bubble-menu'
  import Placeholder from '@tiptap/extension-placeholder'
  import Document from '@tiptap/extension-document'

  let element
  let editor
  let bubbleMenu
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

  export let content
  export let live
  export let session_id
  export let version

  let lastKnownVersion = version
  let lastKnownContent = content
  let isRemoteUpdate = false
  let pendingUpdates = []
  let updateTimeout

  function getTextLengthBefore(doc, targetPos) {
    let length = 0
    doc.descendants((node, pos) => {
      if (pos >= targetPos) return false
      if (node.isText) length += node.text.length
    })
    return length
  }

  function findNewPosition(doc, oldFrom, adjustment) {
    let newPos = oldFrom + adjustment
    let found = false
    doc.descendants((node, pos) => {
      if (found) return false
      if (node.isText) {
        const endPos = pos + node.text.length
        if (newPos >= pos && newPos <= endPos) {
          found = true
          return false
        }
      }
    })
    return Math.min(newPos, doc.content.size)
  }

  onMount(() => {
    editor = new Editor({
      element: element,
      extensions: [
        StarterKit,
        BubbleMenu.configure({ element: bubbleMenu }),
        Placeholder.configure({ placeholder: 'Note Title' }),
        Document,
      ],
      editorProps: {
        attributes: {
          class:
            'prose max-w-none prose-sm sm:prose-base m-5 p-4 focus:outline-none bg-base-200 shadow-md rounded-lg',
        },
      },
      content: content,
      onUpdate: ({ editor }) => {
        if (isRemoteUpdate) return

        const newContent = editor.getHTML()
        const { from, to } = editor.state.selection
        const oldDoc = editor.state.doc

        pendingUpdates.push({
          oldContent: lastKnownContent,
          newContent: newContent,
          version: lastKnownVersion,
          from: from,
          to: to,
        })

        lastKnownContent = newContent
        clearTimeout(updateTimeout)
        updateTimeout = setTimeout(() => {
          const lastUpdate = pendingUpdates[pendingUpdates.length - 1]
          live.pushEvent('content_updated', {
            old_content: lastUpdate.oldContent,
            new_content: lastUpdate.newContent,
            version: lastUpdate.version,
            from: lastUpdate.from,
            to: lastUpdate.to,
          })
          pendingUpdates = []
        }, 200)
      },
    })

    live.handleEvent(
      'remote_content_updated',
      ({ content, version, from, to }) => {
        if (content !== editor.getHTML()) {
          isRemoteUpdate = true
          const oldDoc = editor.state.doc
          const oldLengthBeforeFrom = getTextLengthBefore(oldDoc, from)
          const oldLengthBeforeTo = getTextLengthBefore(oldDoc, to)

          editor.commands.setContent(content, false)
          const newDoc = editor.state.doc

          const newLengthBeforeFrom = getTextLengthBefore(newDoc, from)
          const newLengthBeforeTo = getTextLengthBefore(newDoc, to)

          const fromAdjustment = newLengthBeforeFrom - oldLengthBeforeFrom
          const toAdjustment = newLengthBeforeTo - oldLengthBeforeTo

          let newFrom = findNewPosition(newDoc, from, fromAdjustment)
          let newTo = findNewPosition(newDoc, to, toAdjustment)

          editor
            .chain()
            .focus()
            .setTextSelection({
              from: Math.max(0, Math.min(newFrom, newDoc.content.size)),
              to: Math.max(0, Math.min(newTo, newDoc.content.size)),
            })
            .run()

          lastKnownContent = content
          lastKnownVersion = version
          isRemoteUpdate = false
        }
      }
    )
  })

  onDestroy(() => {
    if (editor) editor.destroy()
    clearTimeout(updateTimeout)
  })
</script>

<BubbleMenuComponent {editor} {bubbleMenuItems} />
{#if bubbleMenuItems.length > 0}
  <div
    class="flex gap-2 bg-base-100 p-2 rounded-lg shadow-sm"
    bind:this={bubbleMenu}
  >
    {#if editor}
      {#each bubbleMenuItems as item}
        <button
          on:click={item.command}
          class:active={editor.isActive(item.active())}
          class="{editor.isActive(item.active())
            ? 'bg-neutral text-base-100 hover:bg-neutral'
            : 'bg-base-200'} px-2 py-1 rounded-md hover:bg-base-300"
        >
          {item.label}
        </button>
      {/each}
    {/if}
  </div>
{/if}

<div bind:this={element} class="w-full" />
