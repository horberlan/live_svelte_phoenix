<script>
  import { Motion } from 'svelte-motion'
  import { onMount } from 'svelte'

  export let editor = null
  export let onBackgroundSelected = null

  let selectedColor = null
  let isOpen = false
  let hoveredColor = null
  let themeBaseColor = '#F5F5F5'
  let backgroundColors = {}

  let hoverTimeout
  let dropdownElement

  function getThemeBaseColor() {
    if (typeof window === 'undefined') return '#F5F5F5'
    const style = getComputedStyle(document.documentElement)
    const base200 = style.getPropertyValue('--b2')?.trim()
    if (base200) {
      return `hsl(${base200})`
    }
    return '#F5F5F5'
  }

  function initializeColors() {
    // !todo: an array for each theme ;-;
    themeBaseColor = getThemeBaseColor()
    backgroundColors = {
      default: themeBaseColor,
      teal: '#008080',
      blue: '#0000FF',
      red: '#FF0000',
      yellow: '#FFFF00',
      green: '#00FF00',
      purple: '#800080',
      orange: '#FFA500',
      pink: '#FFC0CB',
    }
  }

  function handleColorSelect(colorKey, colorValue) {
    selectedColor = colorKey

    if (editor?.view?.dom) {
      if (colorKey === 'default') {
        editor.view.dom.style.backgroundColor = ''
        editor.view.dom.style.color = ''
      } else {
        editor.view.dom.style.backgroundColor = colorValue
        const textColor = getContrastTextColor(colorValue)
        editor.view.dom.style.color = textColor
      }
    }
    function getContrastTextColor(bg) {
      if (!bg) return 'var(--bc)'

      const div = document.createElement('div')
      div.style.color = bg
      document.body.appendChild(div)
      const rgb = getComputedStyle(div).color
      document.body.removeChild(div)

      const match = rgb.match(/\d+/g)
      if (!match) return 'black'
      const [r, g, b] = match.map(Number)

      // YIQ
      const yiq = (r * 299 + g * 587 + b * 114) / 1000
      return yiq >= 128 ? '#000000' : '#FFFFFF'
    }

    if (onBackgroundSelected) {
      onBackgroundSelected({ color: colorKey, value: colorValue })
    }

    isOpen = false
  }

  function handleMouseEnter() {
    clearTimeout(hoverTimeout)
    isOpen = true
  }

  function handleMouseLeave() {
    hoverTimeout = setTimeout(() => {
      isOpen = false
    }, 150)
  }

  onMount(() => {
    initializeColors()
    selectedColor = 'default'
    if (editor?.view?.dom) {
      editor.view.dom.style.backgroundColor = backgroundColors.default
    }
  })
</script>

<!-- svelte-ignore a11y-no-static-element-interactions -->
<div
  class="relative"
  bind:this={dropdownElement}
  on:mouseenter={handleMouseEnter}
  on:mouseleave={handleMouseLeave}
>
  <button
    type="button"
    on:click={() => (isOpen = !isOpen)}
    class="btn btn-sm btn-outline gap-2 transition-all duration-200 border-none"
    class:btn-active={isOpen}
  >
    <div
      class="w-5 h-5 rounded border-2 border-current"
      style="background-color: {selectedColor && backgroundColors[selectedColor]
        ? backgroundColors[selectedColor]
        : 'transparent'}"
    />
  </button>

  {#if isOpen}
    <Motion
      let:motion
      initial={{ opacity: 0, scale: 0.8, y: -10 }}
      animate={{ opacity: 1, scale: 1, y: 0 }}
      transition={{ duration: 0.3 }}
    >
      <div
        use:motion
        class="absolute top-full mt-2 left-0 bg-base-100 rounded-xl shadow-xl border border-base-300 p-3 z-50 min-w-max"
      >
        <div class="grid grid-cols-5 gap-4">
          <Motion
            let:motion
            initial={{ scale: 1, rotate: 0 }}
            whileHover={{ scale: 1.15, rotate: 5 }}
            whileTap={{ scale: 0.95 }}
            transition={{ stiffness: 0.15, damping: 0.4 }}
          >
            <button
              use:motion
              type="button"
              on:click={() =>
                handleColorSelect('default', backgroundColors.default)}
              on:mouseenter={() => (hoveredColor = 'default')}
              on:mouseleave={() => (hoveredColor = null)}
              class="w-8 h-8 rounded-lg transition-all duration-100 cursor-pointer ring-2 ring-offset-2"
              class:ring-primary={selectedColor === 'default'}
              class:ring-base-300={selectedColor !== 'default'}
              class:ring-offset-base-100={true}
              style="background-color: {backgroundColors.default}"
            />
          </Motion>

          {#each Object.entries(backgroundColors).filter(([key]) => key !== 'default') as [key, color]}
            <Motion
              let:motion
              initial={{ scale: 1, rotate: 0 }}
              whileHover={{ scale: 1.15, rotate: 5 }}
              whileTap={{ scale: 0.95 }}
              transition={{ stiffness: 0.15, damping: 0.4 }}
            >
              <button
                use:motion
                type="button"
                on:click={() => handleColorSelect(key, color)}
                on:mouseenter={() => (hoveredColor = key)}
                on:mouseleave={() => (hoveredColor = null)}
                class="w-8 h-8 rounded-lg transition-all duration-200 cursor-pointer ring-2 ring-offset-2"
                class:ring-primary={selectedColor === key}
                class:ring-base-300={selectedColor !== key}
                class:ring-offset-base-100={true}
                style="background-color: {color}"
                title={key.charAt(0).toUpperCase() + key.slice(1)}
              />
            </Motion>
          {/each}
        </div>

        {#if hoveredColor}
          <Motion
            let:motion
            initial={{ opacity: 0, y: -5 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.15 }}
          >
            <div
              use:motion
              class="mt-2 text-xs text-center text-base-content opacity-70 capitalize"
            >
              {hoveredColor === 'default' ? 'default' : hoveredColor}
            </div>
          </Motion>
        {/if}
      </div>
    </Motion>
  {/if}
</div>

<style>
  :global(.editor-bg-animated) {
    transition: background-color 0.3s ease;
  }
</style>
