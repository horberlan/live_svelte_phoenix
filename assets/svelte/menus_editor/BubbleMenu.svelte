<script>
  import FontFamilyDropdown from './FontFamilyDropdown.svelte'
  import BackgroundSelector from './BackgroundSelector.svelte'
  import TextColorSelector from './TextColorSelector.svelte'
  import { createEventDispatcher } from 'svelte'

  export let editor = null
  export let bubbleMenuItems = []
  export let drawingMode = false
  export let onToggleDrawing = null
  
  const dispatch = createEventDispatcher()
  let menuUpdate = 0

  function handleBackgroundSelected(event) {
    console.log('[BubbleMenu] Received backgroundSelected event:', event.detail)
    dispatch('backgroundSelected', event.detail || event)
    console.log('[BubbleMenu] Forwarded to Editor')
  }

  let lastActiveState = ''
  let updateTimeout = null

  function checkAndUpdateMenu() {
    if (!editor) return
    
    // Build current active state string
    const currentState = bubbleMenuItems
      .map(item => {
        const activeArgs = item.active()
        return Array.isArray(activeArgs) ? editor.isActive(...activeArgs) : false
      })
      .join(',')
    
    // Only update if state actually changed
    if (currentState !== lastActiveState) {
      lastActiveState = currentState
      menuUpdate++
    }
  }

  function debouncedUpdate() {
    if (updateTimeout) clearTimeout(updateTimeout)
    updateTimeout = setTimeout(checkAndUpdateMenu, 50)
  }

  $: if (editor) {
    editor.off('selectionUpdate', debouncedUpdate)
    editor.off('transaction', debouncedUpdate)
    
    editor.on('selectionUpdate', debouncedUpdate)
    editor.on('transaction', debouncedUpdate)
    
    checkAndUpdateMenu()
  }
</script>

{#if bubbleMenuItems.length > 0 && editor}
  {#key menuUpdate}
    <div class="bubble-menu-container">
      {#if onToggleDrawing}
        <button
          type="button"
          on:click={onToggleDrawing}
          class="btn btn-sm {drawingMode ? 'btn-primary' : 'btn-ghost'} transition-all duration-200"
          title={drawingMode ? 'Switch to text mode' : 'Switch to drawing mode'}
        >
          {#if drawingMode}
            Text
          {:else}
            <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="icon icon-tabler icons-tabler-outline icon-tabler-scribble"><path stroke="none" d="M0 0h24v24H0z" fill="none"/><path d="M3 15c2 3 4 4 7 4s7 -3 7 -7s-3 -7 -6 -7s-5 1.5 -5 4s2 5 6 5s8.408 -2.453 10 -5" /></svg>
          {/if}
        </button>
        <div class="separator" />
      {/if}

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
      <TextColorSelector {editor} />
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
