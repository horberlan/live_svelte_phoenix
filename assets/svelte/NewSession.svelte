<script>
  export let current_user

  let intl = {
    btn_create: 'Create a new note',
    login: 'Login to create notes',
    register: 'Register',
  }
</script>

{#if current_user}
  <button class="btn px-2 py-1 rounded-md bg-base" phx-click="new_session">
    {intl.btn_create}
  </button>
  <slot></slot>
{:else}
  <div class="flex gap-2">
    <a href="/users/log_in" class="btn btn-primary">{intl.login}</a>
    <a href="/users/register" class="btn btn-secondary">{intl.register}</a>
  </div>
{/if}
