<script>
  import { Motion } from 'svelte-motion'
  import FontFamilyDropdown from './FontFamilyDropdown.svelte'
  import BackgroundSelector from './BackgroundSelector.svelte'

  export let editor = null
  export let bubbleMenuItems = []

  import { createEventDispatcher } from 'svelte'
  
  const dispatch = createEventDispatcher()
  
  let selectedBackground = null

  function handleBackgroundSelected(event) {
    console.log('[BubbleMenu] Received backgroundSelected event:', event.detail)
    selectedBackground = event.detail || event
    // Forward the event to parent (Editor.svelte)
    dispatch('backgroundSelected', event.detail || event)
    console.log('[BubbleMenu] Forwarded to Editor')
  }
</script>

{#if bubbleMenuItems.length > 0 && editor}
  <Motion
    let:motion
    initial={{ opacity: 0, y: -10 }}
    animate={{ opacity: 1, y: 0 }}
    exit={{ opacity: 0, y: -10 }}
    transition={{ duration: 0.2 }}
  >
    <div
      use:motion
      class="flex items-center gap-2 bg-base-100 p-3 rounded-xl shadow-lg border border-base-300 flex-wrap"
    >
      {#each bubbleMenuItems as item}
        <Motion
          let:motion
          initial={{ scale: 1 }}
          whileHover={{ scale: 1.05 }}
          whileTap={{ scale: 0.95 }}
          transition={{ stiffness: 0.2, damping: 0.4 }}
        >
          <button
            use:motion
            type="button"
            on:click={item.command}
            class="btn btn-sm {editor.isActive(...item.active())
              ? 'btn-neutral'
              : 'btn-ghost'} transition-all duration-200"
            class:active={editor.isActive(...item.active())}
            title={item.label}
          >
            {@html item.label}
          </button>
        </Motion>
      {/each}
      <div class="divider divider-horizontal mx-1" />
      <FontFamilyDropdown {editor} />
      <div class="divider divider-horizontal mx-1" />
      <BackgroundSelector
        {editor}
        on:backgroundSelected={handleBackgroundSelected}
      />
    </div>
  </Motion>
{/if}

<style>
  :global(.btn-ghost:hover) {
    background-color: var(--fallback-b3, oklch(var(--b3) / 1));
  }

  :global(.btn-neutral) {
    @apply transition-colors duration-200;
  }
</style>
