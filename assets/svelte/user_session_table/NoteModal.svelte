<script>
  import { onMount, onDestroy } from 'svelte'

  export let live
  export let sessionId
  export let initialContent = ''
  export let initialMode = 'text' // 'text' or 'drawing'
  export let onClose

  let mode = initialMode
  let modalEl
  let content = initialContent
  let isSaving = false
  let textareaEl

  function handleBackdropClick(e) {
    if (e.target === modalEl) {
      handleClose()
    }
  }

  function handleClose() {
    if (onClose) onClose()
  }

  function toggleMode() {
    mode = mode === 'text' ? 'drawing' : 'text'
  }

  function handleSaveAndOpen() {
    if (!content.trim() && mode === 'text') return
    
    isSaving = true
    
    // Create session with initial content
    if (live) {
      live.pushEvent('create_session_with_content', {
        session_id: sessionId,
        content: content,
        mode: mode
      })
    }
    
    // Redirect to the session page
    setTimeout(() => {
      window.location.href = `/session/${sessionId}`
    }, 100)
  }

  function handleKeydown(e) {
    if (e.key === 'Escape') {
      handleClose()
    }
    if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
      handleSaveAndOpen()
    }
  }

  onMount(() => {
    document.body.style.overflow = 'hidden'
    window.addEventListener('keydown', handleKeydown)
    
    // Focus textarea after mount if in text mode
    if (mode === 'text' && textareaEl) {
      setTimeout(() => textareaEl.focus(), 100)
    }
  })

  onDestroy(() => {
    document.body.style.overflow = ''
    window.removeEventListener('keydown', handleKeydown)
  })
</script>

<div
  bind:this={modalEl}
  class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4"
  on:click={handleBackdropClick}
  on:keydown={(e) => e.key === 'Escape' && handleClose()}
  role="button"
  tabindex="-1"
>
  <div
    class="bg-base-100 rounded-lg shadow-2xl w-full max-w-6xl max-h-[90vh] overflow-hidden flex flex-col"
    role="document"
  >
    <!-- Header -->
    <div class="flex items-center justify-between p-4 border-b border-base-300">
      <div class="flex items-center gap-2">
        <h2 class="text-lg font-semibold">
          {mode === 'text' ? 'Text Note' : 'Drawing Note'}
        </h2>
        <span class="badge badge-sm badge-ghost">{sessionId}</span>
      </div>

      <div class="flex items-center gap-2">
        <button
          class="btn btn-sm btn-ghost gap-2"
          on:click={toggleMode}
          title={mode === 'text' ? 'Switch to drawing' : 'Switch to text'}
        >
          {#if mode === 'text'}
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
              <path d="M3 15c2 3 4 4 7 4s7-3 7-7-3-7-6-7-5 1.5-5 4 2 5 6 5 8.408-2.453 10-5"/>
            </svg>
            Draw
          {:else}
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
              <path d="M4 7V4h16v3M9 20h6M12 4v16"/>
            </svg>
            Text
          {/if}
        </button>

        <div class="divider divider-horizontal mx-0"></div>

        <button
          class="btn btn-sm btn-ghost"
          on:click={handleClose}
          title="Close (Esc)"
        >
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
            <path d="M18 6 6 18M6 6l12 12"/>
          </svg>
        </button>
      </div>
    </div>

    <!-- Content -->
    <div class="flex-1 overflow-y-auto p-6">
      {#if mode === 'text'}
        <div class="max-w-4xl mx-auto">
          <textarea
            bind:this={textareaEl}
            bind:value={content}
            placeholder="Start typing your note..."
            class="textarea textarea-bordered w-full min-h-[400px] text-base leading-relaxed resize-none focus:outline-none focus:ring-2 focus:ring-primary"
          />
        </div>
      {:else}
        <div class="max-w-4xl mx-auto">
          <div class="alert alert-info mb-4">
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="stroke-current shrink-0 w-6 h-6">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
            </svg>
            <span>Drawing mode will open in the full editor. Click "Open Note" to start drawing.</span>
          </div>
        </div>
      {/if}
    </div>

    <!-- Footer -->
    <div class="flex items-center justify-between p-4 border-t border-base-300 bg-base-200">
      <div class="text-sm text-base-content/60">
        {#if mode === 'text'}
          <kbd class="kbd kbd-sm">⌘</kbd> + <kbd class="kbd kbd-sm">Enter</kbd> to save and open
        {/if}
      </div>
      
      <div class="flex gap-2">
        <button
          class="btn btn-ghost"
          on:click={handleClose}
          disabled={isSaving}
        >
          Cancel
        </button>
        <button
          class="btn btn-primary gap-2"
          on:click={handleSaveAndOpen}
          disabled={isSaving || (mode === 'text' && !content.trim())}
        >
          {#if isSaving}
            <span class="loading loading-spinner loading-sm"></span>
            Opening...
          {:else}
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
              <path d="M15 3h6v6M9 21H3v-6M21 3l-7 7M3 21l7-7"/>
            </svg>
            Open Note
          {/if}
        </button>
      </div>
    </div>
  </div>
</div>

<style>
  :global(body:has(.fixed.inset-0)) {
    overflow: hidden;
  }
</style>
