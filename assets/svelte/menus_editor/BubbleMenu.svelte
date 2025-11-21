<script>
  export let editor
  export let bubbleMenuItems = []
  export let DropDownMenu
</script>

{#if bubbleMenuItems.length > 0}
  <div
    class="flex items-center gap-2 bg-base-100 p-3 rounded-xl shadow-lg border border-base-300"
  >
    {#if editor}
      {#each bubbleMenuItems as item}
        <button
          type="button"
          on:click={item.command}
          class="btn btn-sm {editor.isActive(item.active())
            ? 'btn-neutral'
            : 'btn-variant-ghost'} 
                {item.class ?? ''}"
          class:active={editor.isActive(item.active())}
        >
          {@html item.label}
        </button>
      {/each}
      <div class="divider divider-horizontal mx-1"></div>

      <svelte:component this={DropDownMenu} />
    {/if}
  </div>
{/if}
