<script>
  import { onMount } from 'svelte';

  export let docId = 'default-doc';
  export let userName = null;
  export let enableCollaboration = true;

  let isConnected = true; // Assume connected via LiveView
  
  const intl = {
    connected: 'connected',
    disconnected: 'disconnected',
    statusTitle: (connected, docId, userEmail) => 
      `Status: ${connected ? 'Connected' : 'Disconnected'} | DocId: ${docId} | User: ${userEmail || 'Anonymous'}`,
  };
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
  </div>
{/if}
</div>
