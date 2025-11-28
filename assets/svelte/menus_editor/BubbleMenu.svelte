<script>
  import FontFamilyDropdown from './FontFamilyDropdown.svelte'
  import BackgroundSelector from './BackgroundSelector.svelte'
  import TextColorSelector from './TextColorSelector.svelte'
  import { createEventDispatcher, onDestroy } from 'svelte'
  import { derived, writable } from 'svelte/store'

  export let editor = null
  export let bubbleMenuItems = []
  export let drawingMode = false
  export let onToggleDrawing = null

  const dispatch = createEventDispatcher()

  const editorState = writable({
    selection: null,
    marks: [],
  })

  const stateKey = derived(editorState, ($state) => JSON.stringify($state))

  let unsubscribers = []

  function updateEditorState() {
    if (!editor) return

    editorState.set({
      selection: editor.state.selection,
      marks: bubbleMenuItems.map((item) => {
        const args = item.active()
        return Array.isArray(args) ? editor.isActive(...args) : false
      }),
    })
  }

  function handleBackgroundSelected(event) {
    dispatch('backgroundSelected', event.detail || event)
  }

  $: if (editor) {
    unsubscribers.forEach((unsub) => unsub())
    unsubscribers = []

    const handlers = ['update', 'selectionUpdate', 'transaction']
    handlers.forEach((event) => {
      editor.on(event, updateEditorState)
      unsubscribers.push(() => editor.off(event, updateEditorState))
    })

    updateEditorState()
  }

  onDestroy(() => {
    unsubscribers.forEach((unsub) => unsub())
  })
</script>

{#if bubbleMenuItems.length > 0 && editor}
  {#key $stateKey}
    <div
      class="bubble-menu-container"
      role="toolbar"
      aria-label="Formatação de texto"
    >
      {#if onToggleDrawing}
        <button
          type="button"
          on:click={onToggleDrawing}
          class="btn btn-sm {drawingMode ? 'btn-primary' : 'btn-ghost'}"
          title={drawingMode ? 'Modo texto' : 'Modo desenho'}
          aria-pressed={drawingMode}
        >
          {#if drawingMode}
            Texto
          {:else}
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="20"
              height="20"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path
                d="M3 15c2 3 4 4 7 4s7 -3 7 -7s-3 -7 -6 -7s-5 1.5 -5 4s2 5 6 5s8.408 -2.453 10 -5"
              />
            </svg>
          {/if}
        </button>
        <div class="separator" aria-hidden="true" />
      {/if}

      {#each bubbleMenuItems as item}
        {@const activeArgs = item.active()}
        {@const isActive = Array.isArray(activeArgs)
          ? editor.isActive(...activeArgs)
          : false}
        <button
          type="button"
          on:click={() => item.command(editor)}
          class="btn btn-sm {isActive
            ? 'btn-neutral'
            : 'btn-ghost'} hover:scale-105 active:scale-95 transition-all duration-200"
          class:active={isActive}
          title={item.label}
          aria-pressed={isActive}
        >
          {@html item.label}
        </button>
      {/each}

      <div class="separator" aria-hidden="true" />
      <FontFamilyDropdown {editor} />

      <div class="separator" aria-hidden="true" />
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
    background: var(--fallback-b1, oklch(var(--b1)));
    padding: 0.75rem;
    border-radius: 0.75rem;
    box-shadow:
      0 10px 15px -3px rgb(0 0 0 / 0.1),
      0 4px 6px -4px rgb(0 0 0 / 0.1);
    border: 1px solid var(--fallback-bc, oklch(var(--bc) / 0.2));
    white-space: nowrap;
    pointer-events: auto;
    z-index: 50;
  }

  .separator {
    width: 1px;
    height: 1.5rem;
    background: var(--fallback-bc, oklch(var(--bc) / 0.2));
    margin: 0 0.25rem;
    flex-shrink: 0;
  }
</style>
