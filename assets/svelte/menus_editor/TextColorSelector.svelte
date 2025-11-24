<script>
  import { Motion } from 'svelte-motion'
  import { onMount } from 'svelte'
  import { createEventDispatcher } from 'svelte'
  
  export let editor = null
  
  const dispatch = createEventDispatcher()

  let selectedColor = 'default'
  let selectedColorValue = null
  let isOpen = false
  let hoveredColor = null
  let themeTextColor = '#000000'
  let textColors = {}

  let hoverTimeout
  let dropdownElement

  function getThemeTextColor() {
    if (typeof window === 'undefined') return '#000000'
    
    const testDiv = document.createElement('div')
    testDiv.className = 'text-base-content'
    testDiv.style.display = 'none'
    document.body.appendChild(testDiv)
    const computedColor = getComputedStyle(testDiv).color
    document.body.removeChild(testDiv)
    
    return computedColor || '#000000'
  }

  function initializeColors() {
    themeTextColor = getThemeTextColor()
    textColors = {
      default: themeTextColor,
      black: '#000000',
      gray: '#6B7280',
      red: '#EF4444',
      orange: '#F97316',
      yellow: '#EAB308',
      green: '#22C55E',
      teal: '#14B8A6',
      blue: '#3B82F6',
      purple: '#A855F7',
      pink: '#EC4899',
    }
    selectedColorValue = textColors.default
  }

  function handleColorSelect(colorKey, colorValue) {
    if (colorKey === 'default') {
      colorValue = getThemeTextColor()
      textColors.default = colorValue
    }
    
    selectedColor = colorKey
    selectedColorValue = colorValue

    if (editor) {
      const { from, to, empty } = editor.state.selection
      
      if (empty) {
        if (colorKey === 'default') {
          editor.chain().focus().unsetColor().run()
        } else {
          editor.chain().focus().setColor(colorValue).run()
        }
      } else {
        if (colorKey === 'default') {
          editor.chain().focus().setTextSelection({ from, to }).unsetColor().run()
        } else {
          editor.chain().focus().setTextSelection({ from, to }).setColor(colorValue).run()
        }
      }
    }

    dispatch('textColorSelected', { value: colorValue })
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

  $: if (editor) {
    const currentColor = editor.getAttributes('textStyle').color
    if (currentColor && currentColor !== selectedColorValue) {
      const matchingKey = Object.entries(textColors).find(
        ([key, value]) => value === currentColor
      )?.[0]
      
      if (matchingKey) {
        selectedColor = matchingKey
        selectedColorValue = currentColor
      } else {
        selectedColorValue = currentColor
      }
    } else if (!currentColor && selectedColor !== 'default') {
      selectedColor = 'default'
      selectedColorValue = textColors.default
    }
  }

  $: previewColor = selectedColorValue || textColors[selectedColor] || 'currentColor'

  onMount(() => {
    initializeColors()
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
    title="Text Color"
  >
    <svg
      xmlns="http://www.w3.org/2000/svg"
      class="w-5 h-5"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <path d="M4 20h16" />
      <path d="m6 16 6-12 6 12" />
      <path d="M8 12h8" />
      <rect
        x="2"
        y="18"
        width="20"
        height="2"
        fill={previewColor}
        stroke="none"
      />
    </svg>
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
        <div class="grid grid-cols-6 gap-3">
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
              on:mousedown|preventDefault
              on:click={() => handleColorSelect('default', textColors.default)}
              on:mouseenter={() => (hoveredColor = 'default')}
              on:mouseleave={() => (hoveredColor = null)}
              class="w-8 h-8 rounded-lg transition-all duration-100 cursor-pointer ring-2 ring-offset-2 flex items-center justify-center"
              class:ring-primary={selectedColor === 'default'}
              class:ring-base-300={selectedColor !== 'default'}
              class:ring-offset-base-100={true}
              style="background-color: {textColors.default}"
            >
              <span class="text-xs font-bold" style="color: {textColors.default === '#000000' ? '#FFFFFF' : '#000000'}">A</span>
            </button>
          </Motion>

          {#each Object.entries(textColors).filter(([key]) => key !== 'default') as [key, color]}
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
                on:mousedown|preventDefault
                on:click={() => handleColorSelect(key, color)}
                on:mouseenter={() => (hoveredColor = key)}
                on:mouseleave={() => (hoveredColor = null)}
                class="w-8 h-8 rounded-lg transition-all duration-200 cursor-pointer ring-2 ring-offset-2 flex items-center justify-center"
                class:ring-primary={selectedColor === key}
                class:ring-base-300={selectedColor !== key}
                class:ring-offset-base-100={true}
                style="background-color: {color}"
                title={key.charAt(0).toUpperCase() + key.slice(1)}
              >
                <span class="text-xs font-bold text-white">A</span>
              </button>
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
