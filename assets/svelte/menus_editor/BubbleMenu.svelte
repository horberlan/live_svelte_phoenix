<script>
  export let editor
  export let bubbleMenu

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
</script>

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
      > {item.label}</button>
    {/each}
  {/if}
</div>
