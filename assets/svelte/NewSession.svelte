<script>
	// import UserSessionTable from './user_session_table/UserSessionTable.svelte';
  let intl = {
    btn_create: 'Create a new note',
  }
</script>

<button class="btn px-2 py-1 rounded-md bg-base" phx-click="new_session">{intl.btn_create}</button>
<!-- <UserSessionTable /> -->
