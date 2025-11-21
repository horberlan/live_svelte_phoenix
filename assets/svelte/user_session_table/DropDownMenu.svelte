<script>
  import { Motion, useAnimation } from 'svelte-motion'
  import { clsx } from 'clsx'
  import { twMerge } from 'tailwind-merge'

  function cn(...inputs) {
    return twMerge(clsx(inputs))
  }

  let fonts = {
    'cherry-bomb-one-regular': {
      name: 'cherry bomb one',
    },
    'borel-regular': {
      name: 'borel',
    },
    'pacifico-regular': {
      name: 'pacifico',
    },
    'jua-regular': {
      name: 'jua',
    },
    'grand-hotel-regular': {
      name: 'grand hotel',
    },
  }

  let isOpen = false
  let selectedFont = fonts['cherry-bomb-one-regular']
  let dropdownElement
  let hoverTimeout

  let list = {
    visible: {
      clipPath: 'inset(0% 0% 0% 0% round 12px)',
      transition: {
        type: 'spring',
        bounce: 0,
      },
    },
    hidden: {
      clipPath: 'inset(10% 50% 90% 50% round 12px)',
      transition: {
        duration: 0.3,
        type: 'spring',
        bounce: 0,
      },
    },
  }

  let variants = {
    visible: (i) => ({
      opacity: 1,
      scale: 1,
      filter: 'blur(0px)',
      transition: {
        duration: 0.3,
        delay: i * 0.15,
      },
    }),
    hidden: {
      opacity: 0,
      scale: 0.2,
      filter: 'blur(14px)',
    },
  }

  function selectFont(fontCss) {
    selectedFont = fonts[fontCss]
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

  $: selectedFontKey = Object.keys(fonts).find(
    (key) => fonts[key].name === selectedFont.name
  )
</script>

<nav
  bind:this={dropdownElement}
  on:mouseenter={handleMouseEnter}
  on:mouseleave={handleMouseLeave}
  class={cn('max-w-[9rem] w-full space-y-2 z-9 relative', selectedFont)}
>
  <Motion whileTap={{ scale: 0.97 }} let:motion>
    <button
      use:motion
      class="bg-base-200 max-w-[9rem] w-full flex items-center justify-between p-2.5 rounded-xl outline-none"
    >
      <span class={cn(selectedFontKey, 'text-sm font-medium')}>
        {selectedFont.name}
      </span>
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="14"
        height="14"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        class="text-neutral-400 mt-0.5 transition-transform duration-300"
        style="transform: {isOpen ? 'rotate(180deg)' : 'rotate(0deg)'}"
      >
        <path d="M6 9l6 6 6-6" />
      </svg>
    </button>

    <Motion
      animate={isOpen ? 'visible' : 'hidden'}
      variants={list}
      initial="hidden"
      let:motion
    >
      <ul
        use:motion
        class={cn(
          'absolute top-full mt-2 z-[1] max-w-[10rem] w-full space-y-3 p-2.5 bg-base-200 shadow-lg border border-base-300 rounded-xl',
          isOpen ? 'pointer-events-auto' : 'pointer-events-none'
        )}
      >
        {#each Object.entries(fonts) as [key, item]}
          <Motion
            custom={key + 1}
            {variants}
            initial="hidden"
            animate={isOpen ? 'visible' : 'hidden'}
            let:motion
          >
            <li use:motion>
              <button
                on:click={() => selectFont(key)}
                class={cn(
                  `w-full text-left group rounded-md border border-transparent focus-visible:text-neutral-300 focus-visible:border-neutral-800 focus-visible:outline-none hover:bg-base-300 p-1.5 transition-colors`,
                  selectedFontKey === key ? 'bg-base-300' : ''
                )}
              >
                <span class={cn(key, 'text-sm font-medium')}>
                  {item.name}
                </span>
              </button>
            </li>
          </Motion>
        {/each}
      </ul>
    </Motion>
  </Motion>
</nav>