<script>
  import { onMount } from 'svelte'

  let note = ''
  let inputEl

  const handleKeydown = (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
      e.preventDefault()
      inputEl?.focus()
    }
  }

  onMount(() => {
    window.addEventListener('keydown', handleKeydown)
    return () => window.removeEventListener('keydown', handleKeydown)
  })
</script>

<div class="flex justify-center items-center p-4">
  <div class="join">
    <div class="relative join-item">
      <input
        type="text"
        placeholder="Take a note..."
        class="input input-bordered join-item flex-grow bg-base-200 text-base-content border-base-300 min-w-[400px]"
        bind:value={note}
        bind:this={inputEl}
      />
      <kbd class="kbd kbd-xs absolute right-7 top-1 opacity-40">⌘</kbd>
      <kbd class="kbd kbd-xs absolute right-2 top-1 opacity-40">k</kbd>
    </div>

    <button
      class="btn btn-square join-item bg-base-200 text-base-content border-y border-base-300 border-r"
      on:click={() => console.log('Draw')}
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="24"
        height="24"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        class="icon icon-tabler icons-tabler-outline icon-tabler-brush"
        ><path stroke="none" d="M0 0h24v24H0z" fill="none" /><path
          d="M3 21v-4a4 4 0 1 1 4 4h-4"
        /><path d="M21 3a16 16 0 0 0 -12.8 10.2" /><path
          d="M21 3a16 16 0 0 1 -10.2 12.8"
        /><path d="M10.6 9a9 9 0 0 1 4.4 4.4" /></svg
      >
    </button>
  </div>
</div>
