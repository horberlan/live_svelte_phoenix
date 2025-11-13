<script>
  import { onMount, onDestroy } from 'svelte';
  import { CollaborativeClient } from '../../js/collaborative_client';

  export let docId = 'default-doc';
  export let userId = 'user-' + Math.random().toString(36).substr(2, 9);
  export let userName = null;
  export let enableCollaboration = true;

  let collaborativeClient = null;
  let collaborators = [];
  let isConnected = false;

  $: otherCollaborators = collaborators.filter(([id]) => id !== userId);

  
  const intl = {
    connected: 'connected',
    disconnected: 'disconnected',
    statusTitle: (connected, docId, userEmail) => 
      `Status: ${connected ? 'Connected' : 'Disconnected'} | DocId: ${docId} | User: ${userEmail || 'Anonymous'}`,
    person: 'person',
    people: 'people',
    online: 'online',
  };

  function handleCollaboratorChange(collaboratorsList) {
    const uniqueCollaborators = new Map();
    
    collaboratorsList.forEach(([id, info]) => {
      if (!uniqueCollaborators.has(id)) {
        uniqueCollaborators.set(id, info);
      }
    });
    
    collaborators = Array.from(uniqueCollaborators.entries());
  }

  async function initializeCollaboration() {
    if (!enableCollaboration) return;

    try {
      collaborativeClient = new CollaborativeClient(
        docId,
        userId,
        userName,
        null,
        handleCollaboratorChange,
        null
      );

      await collaborativeClient.connect();
      isConnected = true;

      const statusInterval = setInterval(() => {
        if (collaborativeClient) {
          const newStatus = collaborativeClient.getConnectionStatus();
          if (newStatus !== isConnected) {
            isConnected = newStatus;
          }
        }
      }, 1000);

      onDestroy(() => clearInterval(statusInterval));
    } catch (error) {
      isConnected = false;
    }
  }

  onMount(() => {
    if (enableCollaboration) {
      initializeCollaboration();
    }
  });

  onDestroy(() => {
    if (collaborativeClient) {
      collaborativeClient.disconnect();
    }
  });
</script>

<div class="flex flex-col">
{#if enableCollaboration}
  <div class="flex items-center gap-2 z-10 ml-4 mb-4">
    <div title={intl.statusTitle(isConnected, docId, userName)}>
      {#if isConnected}
        <div class="badge badge-soft badge-success">{intl.connected}</div>
      {:else}
        <div class="badge badge-soft badge-error">{intl.disconnected}</div>
      {/if}
    </div>

    {#if collaborators.length > 0}
      <div>
        <div class="inline-grid *:[grid-area:1/1]">
          <div class="status status-info animate-pulse"></div>
          <div class="status status-info"></div>
        </div>
        <span class="text-xs font-medium">
          {collaborators.length} {collaborators.length === 1 ? intl.person : intl.people} {intl.online}
        </span>
      </div>
    {/if}
  </div>
{/if}

{#if enableCollaboration && otherCollaborators.length > 0}
  <section class="mt-2 p-2">
    <div class="flex flex-wrap gap-2">
      {#each otherCollaborators as [id, info] (id)}
        <div class="badge badge-info gap-2 px-3 py-2 bg-base-100 hover:bg-base-300 transition-colors cursor-pointer">
          <div class="relative flex items-center">
            <span class="absolute -left-2 w-2.5 h-2.5 bg-success rounded-full animate-ping"></span>
            <span class="absolute -left-2 w-2.5 h-2.5 bg-success rounded-full"></span>
          </div>
          <span class="font-medium text-xs text-info">{info.email || info.name || id}</span>
        </div>
      {/each}
    </div>
  </section>
{/if}
</div>
