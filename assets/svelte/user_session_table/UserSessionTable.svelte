<script>
  import { onMount } from 'svelte'
  
  export let user_sessions = []
  export let live
  
  const i18n = {
    dragging: 'Dragging',
    shared: 'Shared',
    noTitle: 'Untitled',
    session: 'Session',
    position: 'position',
    dragToReorder: 'Drag to reorder',
    unknownUser: 'Unknown user'
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
      [user_sessions[draggingItemIndex], user_sessions[hoveredItemIndex]] = [
        user_sessions[hoveredItemIndex],
        user_sessions[draggingItemIndex]
      ]
      draggingItemIndex = hoveredItemIndex
    }
  }
  
  $: {
    if (dragPreview && mouseY && mouseX && draggingItem) {
      dragPreview.style.display = 'block'
      dragPreview.style.top = `${mouseY + offsetTop}px`
      dragPreview.style.left = `${mouseX + offsetLeft}px`
      dragPreview.innerHTML = `
        <div class="card bg-base-100 shadow-2xl border-2 border-primary" style="width: 320px; transform: rotate(3deg) scale(1.05);">
          <div class="card-body p-4 bg-gradient-to-br from-primary/10 to-secondary/10">
            <div class="flex items-start justify-between gap-2 mb-2">
              <div class="badge badge-primary badge-sm font-semibold">${i18n.dragging}</div>
              ${draggingItem.shared_users && draggingItem.shared_users.length > 0 ? `<div class="badge badge-secondary badge-sm">${i18n.shared}</div>` : ''}
            </div>
            <h2 class="card-title text-base font-bold leading-tight line-clamp-2">${draggingItem.title || i18n.noTitle}</h2>
          </div>
        </div>
      `
    } else if (dragPreview) {
      dragPreview.style.display = 'none'
    }
  }
  
  function getInitials(email) {
    if (!email || typeof email !== 'string') return '?'
    const parts = email.split('@')[0].split(/[._-]/)
    return parts.map(p => p[0]).join('').toUpperCase().slice(0, 2)
  }
  
  function getDisplayName(email) {
    if (!email || typeof email !== 'string') return i18n.unknownUser
    return email.split('@')[0]
  }
  
  function updateSessionOrder() {
    if (live) {
      const orderedSessionIds = user_sessions.map(s => s.session_id)
      live.pushEvent("update_session_order", { session_ids: orderedSessionIds })
    }
  }
  
  function handleDragStart(e, session, index) {
    const img = new Image()
    img.src = 'data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs='
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
    {#if !user_sessions || user_sessions.length === 0}
      <div class="columns-1 sm:columns-2 lg:columns-3 xl:columns-4 2xl:columns-5 gap-4">
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
      <div class="columns-1 sm:columns-2 lg:columns-3 xl:columns-4 2xl:columns-5 gap-4" role="list">
        {#each user_sessions as session, index (session.session_id)}
          <div 
            role="button"
            class="break-inside-avoid mb-4 transition-all duration-200"
            class:opacity-40={draggingItemId && draggingItemId !== session.session_id}
            class:scale-95={draggingItemId && draggingItemId !== session.session_id}
            draggable="true"
            aria-grabbed={draggingItemId === session.session_id}
            aria-label="{i18n.session} {session.title || i18n.noTitle}, {i18n.position} {index + 1}. {i18n.dragToReorder}"
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
              class="card bg-base-100 shadow-md hover:shadow-xl transition-all duration-300 border border-base-300"
              class:ring-4={draggingItemId === session.session_id}
              class:ring-primary={draggingItemId === session.session_id}
              class:ring-offset-2={draggingItemId === session.session_id}
              class:cursor-grab={!draggingItemId}
              class:cursor-grabbing={draggingItemId === session.session_id}
            >
              <div class="card-body p-4">
                <div class="flex items-start justify-between gap-2 mb-2">
                  <div class="badge badge-primary badge-sm font-semibold">
                    #{index + 1}
                  </div>
                  {#if session.shared_users && session.shared_users.length > 0}
                    <div class="badge badge-secondary badge-sm gap-1">
                      {i18n.shared}
                    </div>
                  {/if}
                </div>
  
                <h2 class="card-title text-base font-bold leading-tight line-clamp-2 min-h-[2.5rem]">
                  {session.title || i18n.noTitle}
                </h2>
  
                <a
                  href="/session/{session.session_id}"
                  data-phx-link="redirect"
                  data-phx-link-state="push"
                  class="link link-primary text-xs font-mono break-all hover:link-hover"
                  title={session.session_id}
                  on:click|stopPropagation
                  draggable="false"
                >
                  {session.session_id}
                </a>
  
                {#if session.shared_users && session.shared_users.length > 0}
                  <div class="space-y-2">
                    {#if session.shared_users.length <= 3}
                      <div class="flex flex-wrap gap-2">
                        {#each session.shared_users as email}
                          <div class="flex items-center gap-2 bg-base-200 rounded-full pl-1 pr-3 py-1">
                            <div class="avatar placeholder">
                              <div class="bg-primary text-primary-content rounded-full w-6 h-6 text-xs">
                                <span>{getInitials(email)}</span>
                              </div>
                            </div>
                            <span class="text-xs truncate max-w-[120px]" title={email}>
                              {getDisplayName(email)}
                            </span>
                          </div>
                        {/each}
                      </div>
                    {:else}
                      <div class="flex items-center gap-2">
                        <div class="avatar-group -space-x-3">
                          {#each session.shared_users.slice(0, 3) as email}
                            <div class="avatar placeholder">
                              <div class="bg-primary text-primary-content rounded-full w-8 h-8 text-xs" title={email}>
                                <span>{getInitials(email)}</span>
                              </div>
                            </div>
                          {/each}
                        </div>
                        {#if session.shared_users.length > 3}
                          <span class="text-xs text-base-content/60 font-semibold">
                            +{session.shared_users.length - 3}
                          </span>
                        {/if}
                      </div>
  
                      <div class="text-xs text-base-content/60 space-y-0.5 mt-2">
                        {#each session.shared_users as email}
                          <div class="truncate" title={email}>
                            • {getDisplayName(email)}
                          </div>
                        {/each}
                      </div>
                    {/if}
                  </div>
                {/if}
  
                <div class="flex items-center gap-2 text-xs text-base-content/60 mt-2">
                  <span class="truncate">{session.updated_at}</span>
                </div>
              </div>
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