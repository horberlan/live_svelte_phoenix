<script>
  import { onMount, onDestroy } from 'svelte'

  export let live

  let localStrokes = []
  let enabled = true
  let isLoading = true
  let canvas
  let ctx
  let isDrawing = false
  let currentPath = ''
  let currentColor = '#000000'
  let strokeWidth = 3.0

  const MAX_PATH_LENGTH = 100000
  const MAX_STROKES_PER_SESSION = 1000
  const STROKE_WARNING_THRESHOLD = 900

  let animationFrameId = null
  let coordinateBuffer = []
  let strokeLimitWarningShown = false
  let clearDisabled = false

  let redoStack = []

  const strokeWidthOptions = [2, 3, 5, 8, 12]

  const colors = [
    { name: 'Black', value: '#000000', class: 'bg-black' },
    { name: 'Red', value: '#EF4444', class: 'bg-red-500' },
    { name: 'Blue', value: '#3B82F6', class: 'bg-blue-500' },
    { name: 'Green', value: '#22C55E', class: 'bg-green-500' },
    { name: 'Purple', value: '#A855F7', class: 'bg-purple-500' },
    { name: 'Yellow', value: '#EAB308', class: 'bg-yellow-500' },
  ]

  const grids = {
    none: `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="currentColor" class="icon icon-tabler icons-tabler-filled icon-tabler-columns-1"><path stroke="none" d="M0 0h24v24H0z" fill="none"/><path d="M18 2a2 2 0 0 1 2 2v16a2 2 0 0 1 -2 2h-12a2 2 0 0 1 -2 -2v-16a2 2 0 0 1 2 -2z" /></svg>`,
    dots: `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="icon icon-tabler icons-tabler-outline icon-tabler-grid-dots"><path stroke="none" d="M0 0h24v24H0z" fill="none"/><path d="M5 5m-1 0a1 1 0 1 0 2 0a1 1 0 1 0 -2 0" /><path d="M12 5m-1 0a1 1 0 1 0 2 0a1 1 0 1 0 -2 0" /><path d="M19 5m-1 0a1 1 0 1 0 2 0a1 1 0 1 0 -2 0" /><path d="M5 12m-1 0a1 1 0 1 0 2 0a1 1 0 1 0 -2 0" /><path d="M12 12m-1 0a1 1 0 1 0 2 0a1 1 0 1 0 -2 0" /><path d="M19 12m-1 0a1 1 0 1 0 2 0a1 1 0 1 0 -2 0" /><path d="M5 19m-1 0a1 1 0 1 0 2 0a1 1 0 1 0 -2 0" /><path d="M12 19m-1 0a1 1 0 1 0 2 0a1 1 0 1 0 -2 0" /><path d="M19 19m-1 0a1 1 0 1 0 2 0a1 1 0 1 0 -2 0" /></svg>`,
    frame: `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="icon icon-tabler icons-tabler-outline icon-tabler-grid-4x4"><path stroke="none" d="M0 0h24v24H0z" fill="none"/><path d="M3 6h18" /><path d="M3 12h18" /><path d="M3 18h18" /><path d="M6 3v18" /><path d="M12 3v18" /><path d="M18 3v18" /></svg>`,
  }

  let selectedGrid = 'none'

  function setGridIcon(mode) {}
  function handlerGridBehavior() {}

  function normalizeStroke(s) {
    return {
      path_data: s.path_data || s.path || '',
      color: s.color || '#000000',
      stroke_width: s.stroke_width || s.strokeWidth || 2.0,
    }
  }

  let unregisterHandlers = []

  onMount(() => {
    console.log('[DrawingCanvas] ===== COMPONENT MOUNTED =====')

    if (live && typeof live.handleEvent === 'function') {
      const h1 = live.handleEvent('new_stroke', (data) => {
        const newStroke = normalizeStroke(data)
        localStrokes = [...localStrokes, newStroke]
        if (ctx) redrawAll()
      })

      const h2 = live.handleEvent('canvas_cleared', (data) => {
        localStrokes = []
        strokeLimitWarningShown = false
        if (ctx) clearCanvas()
      })

      const h3 = live.handleEvent('load_strokes', (data) => {
        const incoming = data.strokes || []
        localStrokes = incoming.map(normalizeStroke)
        if (ctx) redrawAll()
      })

      const h4 = live.handleEvent('stroke_undone', () => {
        // Server confirmed undo - sync local state
        // Remove last stroke from local state (already done by server)
        if (localStrokes.length > 0) {
          localStrokes = localStrokes.slice(0, -1)
          if (ctx) redrawAll()
        }
      })

      unregisterHandlers = [h1, h2, h3, h4].filter(Boolean)
    }

    setTimeout(() => {
      isLoading = false
    }, 100)
  })

  onDestroy(() => {
    unregisterHandlers.forEach((fn) => {
      try {
        fn()
      } catch (e) {}
    })
  })

  $: if (canvas && !ctx) {
    initializeCanvas()
  }

  function initializeCanvas() {
    if (!canvas) return
    ctx = canvas.getContext('2d')
    if (!ctx) return

    const rect = canvas.getBoundingClientRect()
    const dpr = window.devicePixelRatio || 1
    canvas.width = rect.width * dpr
    canvas.height = rect.height * dpr
    ctx.scale(dpr, dpr)
    ctx.lineCap = 'round'
    ctx.lineJoin = 'round'

    if (localStrokes.length > 0) {
      setTimeout(() => redrawAll(), 80)
    }
  }

  function startDrawing(event) {
    if (!enabled || !ctx) return
    if (localStrokes.length >= MAX_STROKES_PER_SESSION) return
    isDrawing = true
    const coords = getCoordinates(event)
    currentPath = `M${coords.x},${coords.y}`
  }

  function draw(event) {
    if (!isDrawing || !enabled || !ctx) return
    event.preventDefault()
    const coords = getCoordinates(event)
    coordinateBuffer.push(coords)
    if (!animationFrameId)
      animationFrameId = requestAnimationFrame(flushCoordinateBuffer)
  }

  function flushCoordinateBuffer() {
    if (coordinateBuffer.length === 0) {
      animationFrameId = null
      return
    }
    coordinateBuffer.forEach(
      (coords) => (currentPath += ` L${coords.x},${coords.y}`)
    )
    coordinateBuffer = []
    drawLine(currentPath, currentColor, strokeWidth)
    animationFrameId = null
  }

  function drawLine(path, color, width = strokeWidth) {
    if (!ctx || !path) return
    ctx.beginPath()
    ctx.strokeStyle = color
    ctx.lineWidth = width
    const points = path.split(' ').filter((p) => p.length > 0)
    points.forEach((point) => {
      if (point.startsWith('M')) {
        const coords = point.slice(1).split(',').map(Number)
        if (coords.length === 2 && !isNaN(coords[0]))
          ctx.moveTo(coords[0], coords[1])
      } else if (point.startsWith('L')) {
        const coords = point.slice(1).split(',').map(Number)
        if (coords.length === 2 && !isNaN(coords[0]))
          ctx.lineTo(coords[0], coords[1])
      }
    })
    ctx.stroke()
  }

  function stopDrawing() {
    if (!isDrawing) return
    if (coordinateBuffer.length > 0) {
      coordinateBuffer.forEach(
        (coords) => (currentPath += ` L${coords.x},${coords.y}`)
      )
      coordinateBuffer = []
      if (animationFrameId) {
        cancelAnimationFrame(animationFrameId)
        animationFrameId = null
      }
    }
    isDrawing = false
    if (currentPath && currentPath.length > 5) {
      if (validateStroke(currentPath, currentColor))
        submitStroke(currentPath, currentColor)
    }
    currentPath = ''
  }

  function validateStroke(path, color) {
    const hexColorRegex = /^#[0-9A-Fa-f]{6}$/
    if (!hexColorRegex.test(color)) return false
    if (path.length > MAX_PATH_LENGTH) return false
    return path.length >= 5
  }

  function submitStroke(path, color) {
    const payload = { path, color, stroke_width: strokeWidth }
    const newStroke = { path_data: path, color, stroke_width: strokeWidth }

    // Clear redo stack on new action (can't redo after new stroke)
    redoStack = []

    localStrokes = [...localStrokes, newStroke]
    drawLine(path, color, strokeWidth)
    try {
      if (live && live.pushEvent) live.pushEvent('stroke_drawn', payload)
    } catch (e) {
      console.error('[DrawingCanvas] Error pushing stroke_drawn:', e)
    }
  }

  function handleUndo() {
    if (localStrokes.length === 0) return

    // Save current stroke to redo stack before removing
    const strokeToUndo = localStrokes[localStrokes.length - 1]
    redoStack = [...redoStack, strokeToUndo]

    // Update local state immediately for responsiveness
    localStrokes = localStrokes.slice(0, -1)
    if (ctx) redrawAll()

    // Sync with server (will delete from DB and broadcast to others)
    try {
      if (live && live.pushEvent) {
        live.pushEvent('undo_stroke', {})
      }
    } catch (e) {
      console.error('[DrawingCanvas] Error pushing undo_stroke:', e)
    }
  }

  function handleRedo() {
    if (redoStack.length === 0) return

    // Get the stroke to restore from redo stack
    const strokeToRestore = redoStack[redoStack.length - 1]
    redoStack = redoStack.slice(0, -1)

    // Update local state immediately for responsiveness
    localStrokes = [...localStrokes, strokeToRestore]
    if (ctx) redrawAll()

    // Sync with server - send the stroke data to recreate in DB
    try {
      if (live && live.pushEvent) {
        live.pushEvent('redo_stroke', { stroke: strokeToRestore })
      }
    } catch (e) {
      console.error('[DrawingCanvas] Error pushing redo_stroke:', e)
    }
  }

  function clearCanvas() {
    if (!canvas || !ctx) return
    const rect = canvas.getBoundingClientRect()
    ctx.clearRect(0, 0, rect.width, rect.height)
  }

  function handleClear() {
    if (clearDisabled) return

    redoStack = []

    localStrokes = []
    strokeLimitWarningShown = false
    if (ctx) clearCanvas()

    clearDisabled = true
    setTimeout(() => (clearDisabled = false), 1000)

    try {
      if (live && live.pushEvent) live.pushEvent('clear_canvas', {})
    } catch (e) {}
  }

  function redrawAll() {
    if (!ctx || !canvas) return
    clearCanvas()
    if (!localStrokes || localStrokes.length === 0) return
    localStrokes.forEach((stroke, i) => {
      const s = normalizeStroke(stroke)
      if (s.path_data) drawLine(s.path_data, s.color, s.stroke_width)
    })
  }

  function getCoordinates(event) {
    if (!canvas) return { x: 0, y: 0 }
    const rect = canvas.getBoundingClientRect()
    let clientX, clientY
    if (event.touches && event.touches.length > 0) {
      clientX = event.touches[0].clientX
      clientY = event.touches[0].clientY
    } else {
      clientX = event.clientX
      clientY = event.clientY
    }
    return { x: clientX - rect.left, y: clientY - rect.top }
  }

  function selectColor(color) {
    const hexColorRegex = /^#[0-9A-Fa-f]{6}$/
    if (hexColorRegex.test(color)) currentColor = color
    else currentColor = '#000000'
  }
</script>

{#if isLoading}
  <div class="relative mb-4 w-full">
    <div
      class="toolbar-fixed mb-4 p-3 bg-base-100 rounded-lg shadow-md border border-base-300"
    >
      <div class="skeleton h-10 w-full"></div>
    </div>
    <div class="skeleton h-96 w-full rounded-lg"></div>
  </div>
{:else}
  <div class="relative mb-4 w-full">
    <div
      class="toolbar-fixed mb-4 p-2 bg-base-100 rounded-lg shadow-md border border-base-300"
    >
      <div
        class="flex items-center gap-2 flex-wrap justify-between sm:justify-start"
      >
        <button
          type="button"
          class="btn btn-sm btn-ghost gap-2 text-base-content/70 hover:text-base-content"
          on:click={() => live.pushEvent('toggle_drawing_mode', {})}
          title="Voltar ao modo texto"
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
            stroke-linejoin="round"><path d="m15 18-6-6 6-6" /></svg
          >
          <span class="hidden sm:inline">Text</span>
        </button>

        <div
          class="divider divider-horizontal mx-0 h-6 self-center opacity-50"
        ></div>
        <button
          type="button"
          disabled={localStrokes.length === 0}
          class="btn btn-sm btn-ghost gap-2 text-base-content/70 hover:text-base-content disabled:opacity-30"
          on:click={handleUndo}
          title="Desfazer (Undo)"
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
            class="icon icon-tabler icons-tabler-outline icon-tabler-arrow-back-up"
            ><path stroke="none" d="M0 0h24v24H0z" fill="none" /><path
              d="M9 14l-4 -4l4 -4"
            /><path d="M5 10h11a4 4 0 1 1 0 8h-1" /></svg
          >
        </button>
        <button
          type="button"
          disabled={redoStack.length === 0}
          class="btn btn-sm btn-ghost gap-2 text-base-content/70 hover:text-base-content disabled:opacity-30"
          on:click={handleRedo}
          title="Refazer (Redo)"
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
            class="icon icon-tabler icons-tabler-outline icon-tabler-arrow-forward-up"
            ><path stroke="none" d="M0 0h24v24H0z" fill="none" /><path
              d="M15 14l4 -4l-4 -4"
            /><path d="M19 10h-11a4 4 0 1 0 0 8h1" /></svg
          >
        </button>

        <div
          class="divider divider-horizontal mx-0 h-6 self-center opacity-50"
        ></div>
        <div class="dropdown dropdown-bottom">
          <button
            tabindex="0"
            class="btn btn-sm btn-ghost gap-2"
            title="Espessura do traço"
          >
            <div
              class="w-4 h-4 rounded-full bg-current opacity-80"
              style="transform: scale({Math.min(1, strokeWidth / 6 + 0.2)})"
            ></div>
            <span class="text-xs font-mono opacity-70">{strokeWidth}px</span>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="12"
              height="12"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
              class="opacity-50"
              ><path d="m6 9 6 6 6-6" />
            </svg>
          </button>
          <ul
            class="dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box w-32 border border-base-200"
          >
            {#each strokeWidthOptions as width}
              <li>
                <button
                  type="button"
                  class="flex items-center gap-3 {strokeWidth === width
                    ? 'active'
                    : ''}"
                  on:click={() => (strokeWidth = width)}
                >
                  <div
                    class="h-0 w-8 bg-current rounded-full"
                    style="height: {width}px; min-height: 2px;"
                  ></div>
                  <span class="text-xs">{width}px</span>
                </button>
              </li>
            {/each}
          </ul>
        </div>

        <div
          class="divider divider-horizontal mx-0 h-6 self-center opacity-50"
        ></div>

        <div
          class="flex items-center gap-1 p-1 bg-base-200/50 rounded-lg border border-base-200/50"
        >
          {#each colors as color}
            <button
              type="button"
              class="btn btn-xs btn-circle border-none hover:scale-110 transition-transform relative"
              class:ring-2={currentColor === color.value}
              class:ring-offset-1={currentColor === color.value}
              class:ring-offset-base-100={currentColor === color.value}
              class:ring-primary={currentColor === color.value}
              style="background-color: {color.value};"
              on:click={() => selectColor(color.value)}
              aria-label={color.name}
              title={color.name}
            >
              {#if currentColor === color.value}
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  width="12"
                  height="12"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="#fff"
                  stroke-width="4"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  ><polyline points="20 6 9 17 4 12"></polyline></svg
                >
              {/if}
            </button>
          {/each}

          <div
            class="relative tooltip tooltip-bottom"
            data-tip="Cor Personalizada"
          >
            <div
              class="w-6 h-6 rounded-full ml-1 overflow-hidden border border-base-300 hover:border-primary cursor-pointer relative flex items-center justify-center transition-all shadow-sm"
            >
              <div
                class="absolute inset-0 bg-gradient-to-br from-red-400 via-green-400 to-blue-400 opacity-80"
              ></div>
              <input
                type="color"
                class="absolute inset-0 w-full h-full opacity-0 cursor-pointer p-0 border-0"
                bind:value={currentColor}
                on:change={(e) => selectColor(e.target.value)}
                title="Selecionar cor personalizada"
              />
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="10"
                height="10"
                viewBox="0 0 24 24"
                fill="none"
                stroke="white"
                stroke-width="3"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="relative z-10 drop-shadow-md"
                ><path d="M12 5v14M5 12h14" /></svg
              >
            </div>
          </div>
        </div>
        {@html grids[selectedGrid]}

        <div class="flex-grow"></div>
        <div class="flex items-center gap-2">
          <span
            class="text-xs font-mono opacity-50 hidden sm:inline-block"
            title="Strokes"
          >
            <span class="text-[10px]"
              >{localStrokes.length}/{MAX_STROKES_PER_SESSION}</span
            >
          </span>

          <button
            type="button"
            class="btn btn-sm btn-ghost text-error hover:bg-error/10 hover:text-error"
            on:click={handleClear}
            title="Limpar tudo"
            disabled={clearDisabled}
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
              class="icon icon-tabler icons-tabler-outline icon-tabler-eraser"
              ><path stroke="none" d="M0 0h24v24H0z" fill="none" /><path
                d="M19 20h-10.5l-4.21 -4.3a1 1 0 0 1 0 -1.41l10 -10a1 1 0 0 1 1.41 0l5 5a1 1 0 0 1 0 1.41l-9.2 9.3"
              /><path d="M18 13.3l-6.3 -6.3" /></svg
            >
          </button>
        </div>
      </div>
    </div>

    <canvas
      bind:this={canvas}
      class="drawing-canvas block w-full bg-base-300 rounded-lg shadow-inner border border-base-200"
      style="height: 1200px; display: block;"
      on:mousedown={startDrawing}
      on:mousemove={draw}
      on:mouseup={stopDrawing}
      on:mouseleave={stopDrawing}
      on:touchstart|nonpassive={startDrawing}
      on:touchmove|nonpassive={draw}
      on:touchend|nonpassive={stopDrawing}
      aria-label="Drawing canvas"
    />
  </div>
{/if}

<style>
  .drawing-canvas {
    touch-action: none;
  }
  .drawing-canvas_grid-dots {
    background-image: radial-gradient(#e5e7eb 1px, transparent 1px);
    background-size: 20px 20px;
  }
  .drawing-canvas_grid-none {
  }
  .drawing-canvas_grid-frame {
  }

  .toolbar-fixed {
    position: sticky;
    top: 0;
    z-index: 30;
  }
  canvas {
    cursor:
      url('data:image/svg+xml;utf8,<svg width="32" height="32" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" clip-rule="evenodd" d="M4.49116 10.3175L3.35405 5.68851C2.93458 3.98089 4.76445 2.60198 6.2903 3.47589L10.4265 5.84487C11.1996 5.62294 12.0633 5.88333 12.5762 6.564L23.4089 20.9394C24.0737 21.8216 23.8974 23.0756 23.0153 23.7403L18.2235 27.3512C17.3413 28.016 16.0873 27.8397 15.4226 26.9576L4.58989 12.5821C4.07697 11.9015 4.06475 10.9994 4.49116 10.3175ZM5.58535 10.5799L4.32518 5.44995C4.11544 4.59614 5.03038 3.90669 5.79331 4.34364L10.3772 6.96899C10.8182 6.63662 11.4452 6.72474 11.7776 7.16581L22.6103 21.5412C22.9426 21.9823 22.8545 22.6093 22.4135 22.9417L17.6216 26.5526C17.1806 26.885 16.5536 26.7968 16.2212 26.3558L5.38853 11.9803C5.05615 11.5393 5.14427 10.9123 5.58535 10.5799Z" fill="white"/><path d="M4.32518 5.44996L5.58534 10.5799C5.14427 10.9123 5.05615 11.5393 5.38852 11.9803L16.2212 26.3558C16.5536 26.7969 17.1806 26.885 17.6216 26.5526L22.4135 22.9417C22.8545 22.6093 22.9426 21.9823 22.6103 21.5413L11.7776 7.16582C11.4452 6.72474 10.8182 6.63662 10.3772 6.969L5.7933 4.34365C5.03038 3.90669 4.11544 4.59615 4.32518 5.44996Z" fill="%23FF8CFF"/><path fill-rule="evenodd" clip-rule="evenodd" d="M22.6103 21.5413C22.9427 21.9823 22.8546 22.6093 22.4135 22.9417L20.0176 24.7472L18.814 23.1499L22.0085 20.7426L12.3794 7.96448L9.18491 10.3717L4.69453 4.41278C4.99241 4.18831 5.41187 4.12519 5.79334 4.34366L10.3772 6.96901C10.8183 6.63664 11.4453 6.72476 11.7776 7.16583L22.6103 21.5413ZM9.18491 10.3717L18.814 23.1499L15.6194 25.5572L5.99036 12.779L9.18491 10.3717Z" fill="%23FFB1FF"/><path d="M18.814 23.1499L22.0085 20.7426L12.3794 7.96448L9.18491 10.3717L18.814 23.1499Z" fill="%23FFC4FF"/><path d="M15.2495 25.0568L14.62 24.2214C14.7416 24.0342 14.8345 23.8444 14.925 23.6497C14.9418 23.6135 14.9587 23.5767 14.9758 23.5392C15.1763 23.1017 15.4152 22.5805 15.9829 22.1528C16.5735 21.7077 17.2367 21.5747 17.782 21.4652L17.8172 21.4582C18.3982 21.3415 18.8519 21.2429 19.2468 20.9454C19.6068 20.6741 19.7482 20.3686 19.96 19.9111L19.9996 19.8256C20.1413 19.5208 20.3082 19.1841 20.5819 18.84L21.2114 19.6754C21.0898 19.8626 20.997 20.0524 20.9065 20.2471C20.8897 20.2832 20.8728 20.3201 20.8556 20.3576C20.6551 20.7951 20.4163 21.3162 19.8486 21.744C19.2579 22.1891 18.5948 22.3221 18.0494 22.4315L18.0142 22.4386C17.4332 22.5553 16.9795 22.6539 16.5847 22.9514C16.2246 23.2227 16.0832 23.5282 15.8714 23.9857L15.8318 24.0711C15.6901 24.376 15.5232 24.7128 15.2495 25.0568Z" fill="%23B37CB3"/><path d="M7.42144 14.6781L6.79192 13.8427C6.91357 13.6555 7.00638 13.4657 7.09689 13.2709C7.11369 13.2348 7.13059 13.1979 7.14777 13.1604C7.34825 12.723 7.58711 12.2018 8.15477 11.774C8.74542 11.329 9.40859 11.1959 9.95395 11.0865L9.98917 11.0794C10.5701 10.9627 11.0238 10.8642 11.4187 10.5666C11.7787 10.2953 11.9201 9.98986 12.1319 9.53234L12.1716 9.4469C12.3132 9.14205 12.4802 8.80532 12.7538 8.46126L13.3833 9.29667C13.2617 9.48385 13.1689 9.67364 13.0784 9.86837C13.0616 9.90451 13.0447 9.94138 13.0275 9.97886C12.827 10.4163 12.5882 10.9375 12.0205 11.3653C11.4299 11.8103 10.7667 11.9434 10.2213 12.0528L10.1861 12.0599C9.60517 12.1766 9.15146 12.2751 8.75659 12.5727C8.39656 12.844 8.25515 13.1494 8.04334 13.607L8.00373 13.6924C7.86204 13.9973 7.69511 14.334 7.42144 14.6781Z" fill="%23B37CB3"/></svg>')
        4 0,
      auto;
  }
</style>
