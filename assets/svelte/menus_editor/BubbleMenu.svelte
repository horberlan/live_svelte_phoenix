<script>
  export let editor
  export let bubbleMenuItems = []
</script>

{#if bubbleMenuItems.length > 0}
  <div class="flex gap-2 bg-gray-100 p-2 rounded-lg shadow-sm w-full">
    {#if editor}
      {#each bubbleMenuItems as item}
        <button
          on:click={item.command}
          class:active={editor.isActive(item.active())}
          class="
        {editor.isActive(item.active()) ? 'bg-neutral text-base-100 hover:bg-neutral' : 'bg-base-200'}
        px-2 py-1 rounded-md hover:bg-base-300 focus:outline-none"
        >
          {item.label}</button
        >
      {/each}
    {/if}
  </div>
{/if}
