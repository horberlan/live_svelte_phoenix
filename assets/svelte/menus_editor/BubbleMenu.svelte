<script>
  import FontFamilyDropdown from './FontFamilyDropdown.svelte'
  import BackgroundSelector from './BackgroundSelector.svelte'
  import { createEventDispatcher } from 'svelte'

  export let editor = null
  export let bubbleMenuItems = []
  
  const dispatch = createEventDispatcher()
  let menuUpdate = 0 // Force menu update (same approach as toolbar)

  function handleBackgroundSelected(event) {
    console.log('[BubbleMenu] Received backgroundSelected event:', event.detail)
    // Forward the event to parent (Editor.svelte)
    dispatch('backgroundSelected', event.detail || event)
    console.log('[BubbleMenu] Forwarded to Editor')
  }

  // Function to update menu
  function updateMenu() {
    menuUpdate++
  }

  // Setup editor listeners when editor changes
  $: if (editor) {
    // Remove old listeners if they exist
    editor.off('selectionUpdate', updateMenu)
    editor.off('transaction', updateMenu)
    
    // Add new listeners
    editor.on('selectionUpdate', updateMenu)
    editor.on('transaction', updateMenu)
    
    // Initial update
    updateMenu()
  }
</script>

{#if bubbleMenuItems.length > 0 && editor}
  {#key menuUpdate}
    <div class="bubble-menu-container">
      {#each bubbleMenuItems as item, index}
        {@const activeArgs = item.active()}
        {@const isActive = Array.isArray(activeArgs) ? editor.isActive(...activeArgs) : false}
        <button
          type="button"
          on:click={() => {
            item.command()
            setTimeout(updateMenu, 10)
          }}
          class="btn btn-sm {isActive ? 'btn-neutral' : 'btn-ghost'} transition-all duration-200 hover:scale-105 active:scale-95"
          title={item.label}
        >
          {@html item.label}
        </button>
      {/each}
      <div class="separator" />
      <FontFamilyDropdown {editor} />
      <div class="separator" />
      <BackgroundSelector
        {editor}
        on:backgroundSelected={handleBackgroundSelected}
      />
    </div>
  {/key}
{/if}

<style>
  .bubble-menu-container {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    background-color: var(--fallback-b1, oklch(var(--b1) / 1));
    padding: 0.75rem;
    border-radius: 0.75rem;
    box-shadow: 0 10px 15px -3px rgb(0 0 0 / 0.1), 0 4px 6px -4px rgb(0 0 0 / 0.1);
    border: 1px solid var(--fallback-bc, oklch(var(--bc) / 0.2));
    white-space: nowrap;
    pointer-events: auto;
  }
  
  .separator {
    width: 1px;
    height: 1.5rem;
    background-color: var(--fallback-bc, oklch(var(--bc) / 0.2));
    margin: 0 0.25rem;
  }

  :global(.btn-ghost:hover) {
    background-color: var(--fallback-b3, oklch(var(--b3) / 1));
  }

  :global(.btn-neutral) {
    transition: colors 0.2s;
  }
</style>
