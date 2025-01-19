<script>
  import ConnectButton from './ConnectButton.svelte'
  // import UserSessionTable from './user_session_table/UserSessionTable.svelte';

  let intl = {
    btn_create: 'Create a new note',
    tooltip: 'connect your phantom wallet first',
  }
  export let live
  
  let canCreateSession = false
</script>

<ConnectButton {live} bind:canCreateSession />
{#if !canCreateSession}
  <div class="tooltip tooltip-right" data-tip={intl.tooltip}>
    <button
      class="btn px-2 py-1 rounded-md bg-base"
      phx-click="new_session"
      disabled={!canCreateSession}>{intl.btn_create}</button
    >
  </div>
{:else}
  <button class="btn px-2 py-1 rounded-md bg-base" phx-click="new_session"
    >{intl.btn_create}</button
  >
{/if}
<!-- <UserSessionTable /> -->
