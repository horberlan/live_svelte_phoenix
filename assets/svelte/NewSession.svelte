<script>
  import { onMount } from 'svelte'
  import UserSessionTable from './user_session_table/UserSessionTable.svelte'

  export let current_user

  let intl = {
    btn_create: 'Create a new note',
  }

  onMount(() => {
    console.log('Current User:', current_user)
  })
</script>

{#if current_user}
  <button class="btn px-2 py-1 rounded-md bg-base" phx-click="new_session">
    {intl.btn_create}
  </button>
{:else}
  <div class="flex gap-2">
    <a href="/users/log_in" class="btn btn-primary">Login to create notes</a>
    <a href="/users/register" class="btn btn-secondary">Register</a>
  </div>
{/if}
<UserSessionTable />
