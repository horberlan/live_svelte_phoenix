<script>
  import { onMount } from 'svelte'
  import SimpleEditor from './SimpleEditor.svelte'

  export let live

  let note = ''
  let inputEl
  let showEditor = false
  let editorMode = 'text' // 'text' or 'drawing'

  const handleKeydown = (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
      e.preventDefault()
      inputEl?.focus()
    }
  }

  function handleFocus() {
    if (!showEditor) {
      editorMode = 'text'
      showEditor = true
    }
  }

  function handleDrawMode() {
    editorMode = 'drawing'
    showEditor = true
  }

  function handleCloseEditor() {
    showEditor = false
    setTimeout(() => {
      note = ''
    }, 400)
  }

  onMount(() => {
    window.addEventListener('keydown', handleKeydown)
    return () => window.removeEventListener('keydown', handleKeydown)
  })
</script>

<div class="w-full px-4">
  <div class="flex justify-center items-center py-4">
    <div class="join">
      <div class="relative join-item">
        <input
          type="text"
          placeholder="Take a note..."
          class="input input-bordered join-item flex-grow bg-base-200 text-base-content border-base-300 min-w-[400px]"
          bind:value={note}
          bind:this={inputEl}
          on:focus={handleFocus}
          on:keydown={handleKeydown}
        />
        <kbd class="kbd kbd-xs absolute right-7 top-1 opacity-40">⌘</kbd>
        <kbd class="kbd kbd-xs absolute right-2 top-1 opacity-40">k</kbd>
      </div>

      <button
        class="btn btn-square join-item bg-base-200 text-base-content border-y border-base-300 border-r hover:bg-primary hover:text-primary-content transition-colors"
        on:click={handleDrawMode}
        title="Create drawing note"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="18"
          height="18"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <path
            d="M3 15c2 3 4 4 7 4s7-3 7-7-3-7-6-7-5 1.5-5 4 2 5 6 5 8.408-2.453 10-5"
          />
        </svg>
      </button>
    </div>
  </div>

  {#if showEditor}
    <SimpleEditor
      {live}
      initialContent={note}
      initialMode={editorMode}
      onClose={handleCloseEditor}
    />
  {/if}
</div>
