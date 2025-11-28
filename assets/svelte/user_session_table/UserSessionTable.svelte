<script>
  import { onMount } from 'svelte'
  import NoteInput from './NoteInput.svelte'
  import HomeEditor from './HomeEditor.svelte'
  export let user_sessions = []
  export let live

  /**
   * Corrige double-encoding UTF-8
   * Quando o LiveView/LiveSvelte serializa dados, UTF-8 pode ser interpretado como Latin-1
   * Esta função reverte esse processo
   */
  function fixDoubleEncoding(text) {
    if (!text || typeof text !== 'string') return text

    // Verificar se tem marcadores de double-encoding
    if (!text.includes('Ã') && !text.includes('ð') && !text.includes('â')) {
      return text
    }

    try {
      // Method 1: Use TextEncoder/TextDecoder
      // Encode string as if it were Latin-1, then decode as UTF-8
      const latin1Bytes = []
      for (let i = 0; i < text.length; i++) {
        latin1Bytes.push(text.charCodeAt(i) & 0xff)
      }
      const utf8String = new TextDecoder('utf-8').decode(
        new Uint8Array(latin1Bytes)
      )

      // Check if correction improved the string
      if (!utf8String.includes('Ã') && !utf8String.includes('ð')) {
        return utf8String
      }

      return text
    } catch (e) {
      console.error('[fixDoubleEncoding] Erro:', e)
      return text
    }
  }

  // Fix encoding of all sessions when received
  $: corrected_sessions = user_sessions.map((session) => ({
    ...session,
    title: fixDoubleEncoding(session.title),
  }))

  const i18n = {
    dragging: 'Dragging',
    shared: 'Shared',
    noTitle: 'Untitled',
    session: 'Session',
    position: 'position',
    dragToReorder: 'Drag to reorder',
    unknownUser: 'Unknown user',
  }

  let mouseY = null
  let mouseX = null
  let offsetTop = null
  let offsetLeft = null
  let draggingItem = null
  let draggingItemId = null
  let draggingItemIndex = null
  let hoveredItemIndex = null
  let dragPreview = null

  onMount(() => {
    dragPreview = document.createElement('div')
    dragPreview.style.position = 'fixed'
    dragPreview.style.pointerEvents = 'none'
    dragPreview.style.zIndex = '9999'
    dragPreview.style.display = 'none'
    document.body.appendChild(dragPreview)

    return () => {
      if (dragPreview && dragPreview.parentNode) {
        dragPreview.parentNode.removeChild(dragPreview)
      }
    }
  })

  $: {
    if (
      draggingItemIndex != null &&
      hoveredItemIndex != null &&
      draggingItemIndex != hoveredItemIndex
    ) {
      ;[
        corrected_sessions[draggingItemIndex],
        corrected_sessions[hoveredItemIndex],
      ] = [
        corrected_sessions[hoveredItemIndex],
        corrected_sessions[draggingItemIndex],
      ]
      draggingItemIndex = hoveredItemIndex
    }
  }

  $: {
    if (dragPreview && mouseY && mouseX && draggingItem) {
      dragPreview.style.display = 'block'
      dragPreview.style.top = `${mouseY + offsetTop}px`
      dragPreview.style.left = `${mouseX + offsetLeft}px`

      // Clear previous content and append new safe content
      dragPreview.innerHTML = ''
      dragPreview.appendChild(createDragPreview(draggingItem))
    } else if (dragPreview) {
      dragPreview.style.display = 'none'
    }
  }

  function getInitials(email) {
    if (!email || typeof email !== 'string') return '?'
    const parts = email.split('@')[0].split(/[._-]/)
    return parts
      .map((p) => p[0])
      .join('')
      .toUpperCase()
      .slice(0, 2)
  }

  function getDisplayName(email) {
    if (!email || typeof email !== 'string') return i18n.unknownUser
    return email.split('@')[0]
  }

  function createDragPreview(draggingItem) {
    // Create main card container
    const cardDiv = document.createElement('div')
    cardDiv.className = 'card bg-base-100 shadow-2xl border-2 border-primary'
    cardDiv.style.width = '320px'
    cardDiv.style.transform = 'rotate(3deg) scale(1.05)'

    // Create card body
    const cardBody = document.createElement('div')
    cardBody.className =
      'card-body p-4 bg-gradient-to-br from-primary/10 to-secondary/10'

    // Create badges container
    const badgesContainer = document.createElement('div')
    badgesContainer.className = 'flex items-start justify-between gap-2 mb-2'

    // Create dragging badge
    const draggingBadge = document.createElement('div')
    draggingBadge.className = 'badge badge-primary badge-sm font-semibold'
    draggingBadge.textContent = i18n.dragging
    badgesContainer.appendChild(draggingBadge)

    // Create shared badge if needed
    if (draggingItem.shared_users && draggingItem.shared_users.length > 0) {
      const sharedBadge = document.createElement('div')
      sharedBadge.className = 'badge badge-secondary badge-sm'
      sharedBadge.textContent = i18n.shared
      badgesContainer.appendChild(sharedBadge)
    }

    // Create title element
    const titleElement = document.createElement('h2')
    titleElement.className =
      'card-title text-base font-bold leading-tight line-clamp-2'
    // Use textContent to safely handle Unicode characters and prevent XSS
    titleElement.textContent = draggingItem.title || i18n.noTitle

    // Assemble the structure
    cardBody.appendChild(badgesContainer)
    cardBody.appendChild(titleElement)
    cardDiv.appendChild(cardBody)

    return cardDiv
  }

  function updateSessionOrder() {
    if (live) {
      const orderedSessionIds = corrected_sessions.map((s) => s.session_id)
      live.pushEvent('update_session_order', { session_ids: orderedSessionIds })
    }
  }

  function handleDragStart(e, session, index) {
    const img = new Image()
    img.src =
      'data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs='
    e.dataTransfer.setDragImage(img, 0, 0)
    e.dataTransfer.effectAllowed = 'move'

    mouseY = e.clientY
    mouseX = e.clientX
    draggingItem = session
    draggingItemIndex = index
    draggingItemId = session.session_id

    const rect = e.currentTarget.getBoundingClientRect()
    offsetTop = rect.top - e.clientY
    offsetLeft = rect.left - e.clientX
  }

  function handleDrag(e) {
    e.preventDefault()
    if (e.clientY !== 0) mouseY = e.clientY
    if (e.clientX !== 0) mouseX = e.clientX
  }

  function handleDragOver(e, index) {
    e.preventDefault()
    e.dataTransfer.dropEffect = 'move'
    hoveredItemIndex = index
  }

  function handleDragEnd(e) {
    e.preventDefault()

    const wasDragging = draggingItemId !== null

    draggingItem = null
    draggingItemId = null
    draggingItemIndex = null
    hoveredItemIndex = null
    mouseY = null
    mouseX = null

    if (wasDragging) {
      requestAnimationFrame(() => {
        setTimeout(() => {
          updateSessionOrder()
        }, 50)
      })
    }
  }
</script>

<div class="w-full p-4">
  <!-- <NoteInput {live} /> -->
  <HomeEditor {live} />
  {#if !corrected_sessions || corrected_sessions.length === 0}
    <div
      class="columns-1 sm:columns-2 lg:columns-3 xl:columns-4 2xl:columns-5 gap-4"
    >
      {#each [1, 2, 3, 4, 5, 6, 7, 8] as _}
        <div class="break-inside-avoid mb-4">
          <div class="card bg-base-200 skeleton">
            <div class="card-body space-y-3">
              <div class="h-6 bg-base-300 rounded w-3/4"></div>
              <div class="h-4 bg-base-300 rounded w-full"></div>
              <div class="h-4 bg-base-300 rounded w-1/2"></div>
            </div>
          </div>
        </div>
      {/each}
    </div>
  {:else}
    <div
      class="columns-1 sm:columns-2 lg:columns-3 xl:columns-4 2xl:columns-5 gap-4"
      role="list"
    >
      {#each corrected_sessions as session, index (session.session_id)}
        <div
          role="button"
          class="break-inside-avoid mb-4 transition-all duration-200"
          class:opacity-40={draggingItemId &&
            draggingItemId !== session.session_id}
          class:scale-95={draggingItemId &&
            draggingItemId !== session.session_id}
          draggable="true"
          aria-grabbed={draggingItemId === session.session_id}
          aria-label="{i18n.session} {session.title ||
            i18n.noTitle}, {i18n.position} {index + 1}. {i18n.dragToReorder}"
          tabindex="0"
          on:dragstart={(e) => handleDragStart(e, session, index)}
          on:drag={handleDrag}
          on:dragover={(e) => handleDragOver(e, index)}
          on:dragend={handleDragEnd}
          on:keydown={(e) => {
            if (e.key === 'Enter' || e.key === ' ') {
              e.preventDefault()
            }
          }}
        >
          <div
            class="card bg-base-100 hover:shadow-xl transition-all duration-300 border border-base-300"
            class:ring-4={draggingItemId === session.session_id}
            class:ring-primary={draggingItemId === session.session_id}
            class:ring-offset-2={draggingItemId === session.session_id}
            class:cursor-grab={!draggingItemId}
            class:cursor-grabbing={draggingItemId === session.session_id}
          >
            <a
              href="/session/{session.session_id}"
              data-phx-link="redirect"
              data-phx-link-state="push"
              class="link link-primary break-all no-underline hover:no-underline after:hidden hover:after:hidden"
              title={session.session_id}
              on:click|stopPropagation
              draggable="false"
            >
              <div class="card-body p-4">
                {#if session.shared_users && session.shared_users.length > 0}
                  <div class="flex items-start justify-between gap-2">
                    <div class="badge badge-secondary badge-xs gap-1 py-2">
                      {i18n.shared}
                    </div>
                  </div>
                {/if}

                <h2
                  class="card-title text-base font-bold leading-tight line-clamp-2"
                >
                  {session.title || i18n.noTitle}
                </h2>
                {#if session.shared_users && session.shared_users.length > 0}
                  <div class="mt-2">
                    <div class="flex items-center gap-2">
                      <div class="avatar-group -space-x-3">
                        {#each session.shared_users.slice(0, 4) as email}
                          <div class="avatar placeholder">
                            <div
                              class="bg-primary text-primary-content rounded-full w-8 h-8 text-xs ring ring-base-100"
                              title={email}
                            >
                              <span>{getInitials(email)}</span>
                            </div>
                          </div>
                        {/each}
                        {#if session.shared_users.length > 4}
                          <div class="avatar placeholder">
                            <div
                              class="bg-base-300 text-base-content rounded-full w-8 h-8 text-xs ring ring-base-100"
                              title="{session.shared_users.length -
                                4} more users"
                            >
                              <span>+{session.shared_users.length - 4}</span>
                            </div>
                          </div>
                        {/if}
                      </div>
                    </div>
                  </div>
                {/if}

                <div
                  class="flex items-center gap-2 text-xs text-base-content/60 mt-2"
                >
                  <span class="truncate">{session.updated_at}</span>
                </div>
              </div>
            </a>
          </div>
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .break-inside-avoid {
    break-inside: avoid;
    page-break-inside: avoid;
  }

  .card {
    transform: translateZ(0);
    backface-visibility: hidden;
  }

  .line-clamp-2 {
    display: -webkit-box;
    line-clamp: 2;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }

  .cursor-grab {
    cursor: grab;
  }

  .cursor-grabbing {
    cursor: grabbing;
  }
</style>
