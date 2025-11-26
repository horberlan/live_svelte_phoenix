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

  // Opções de espessura para o dropdown
  const strokeWidthOptions = [2, 3, 5, 8, 12]

  const colors = [
    { name: 'Black', value: '#000000', class: 'bg-black' },
    { name: 'Red', value: '#EF4444', class: 'bg-red-500' },
    { name: 'Blue', value: '#3B82F6', class: 'bg-blue-500' },
    { name: 'Green', value: '#22C55E', class: 'bg-green-500' },
    { name: 'Purple', value: '#A855F7', class: 'bg-purple-500' },
    { name: 'Yellow', value: '#EAB308', class: 'bg-yellow-500' },
  ]

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
        if (ctx) setTimeout(() => redrawAll(), 50)
      })

      unregisterHandlers = [h1, h2, h3].filter(Boolean)
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
    localStrokes = [...localStrokes, newStroke]
    drawLine(path, color, strokeWidth)
    try {
      if (live && live.pushEvent) live.pushEvent('stroke_drawn', payload)
    } catch (e) {
      console.error('[DrawingCanvas] Error pushing stroke_drawn:', e)
    }
  }

  function clearCanvas() {
    if (!canvas || !ctx) return
    const rect = canvas.getBoundingClientRect()
    ctx.clearRect(0, 0, rect.width, rect.height)
  }

  function handleClear() {
    if (clearDisabled) return
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
  <div class="relative mb-4 w-full max-w-7xl mx-auto">
    <div
      class="toolbar-fixed mb-4 p-3 bg-base-100 rounded-lg shadow-md border border-base-300"
    >
      <div class="skeleton h-10 w-full"></div>
    </div>
    <div class="skeleton h-96 w-full rounded-lg"></div>
  </div>
{:else}
  <div class="relative mb-4 w-full max-w-7xl mx-auto">
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
          disabled="disabled"
          class="btn btn-sm btn-ghost gap-2 text-base-content/70 hover:text-base-content"
          on:click={() => live.pushEvent('undo_last_drawing', {})}
          title="Voltar ao modo texto"
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
          disabled="disabled"
          class="btn btn-sm btn-ghost gap-2 text-base-content/70 hover:text-base-content"
          on:click={() => live.pushEvent('forward_last_drawing', {})}
          title="Voltar ao modo texto"
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
              class="opacity-50"><path d="m6 9 6 6 6-6" /></svg
            >
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

        <div class="flex-grow"></div>
        <div class="flex items-center gap-2">
          <span
            class="text-xs font-mono opacity-50 hidden sm:inline-block"
            title="Strokes"
          >
            {localStrokes.length}
            <span class="text-[10px]">/ {MAX_STROKES_PER_SESSION}</span>
          </span>

          <button
            type="button"
            class="btn btn-sm btn-ghost text-error hover:bg-error/10 hover:text-error"
            on:click={handleClear}
            title="Limpar tudo"
            disabled={clearDisabled}
          >
           <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="icon icon-tabler icons-tabler-outline icon-tabler-eraser"><path stroke="none" d="M0 0h24v24H0z" fill="none"/><path d="M19 20h-10.5l-4.21 -4.3a1 1 0 0 1 0 -1.41l10 -10a1 1 0 0 1 1.41 0l5 5a1 1 0 0 1 0 1.41l-9.2 9.3" /><path d="M18 13.3l-6.3 -6.3" /></svg>
          </button>
        </div>
      </div>
    </div>

    <canvas
      bind:this={canvas}
      class="drawing-canvas block w-full bg-white rounded-lg cursor-crosshair shadow-inner border border-base-200"
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
    background-image: radial-gradient(#e5e7eb 1px, transparent 1px);
    background-size: 20px 20px;
  }
  .toolbar-fixed {
    position: sticky;
    top: 0;
    z-index: 30;
  }
</style>
