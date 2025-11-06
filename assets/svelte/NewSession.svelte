<script>
  export let current_user

  let intl = {
    btn_create: 'Create a new note',
    login: 'Login to create notes',
    register: 'Register',
  }
</script>

{#if current_user}
  <button class="btn btn-square" phx-click="new_session">
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6">
  <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
</svg>
  </button>
  <slot></slot>
{:else}
  <div class="flex gap-2">
    <a href="/users/log_in" class="btn btn-primary">{intl.login}</a>
    <a href="/users/register" class="btn btn-secondary">{intl.register}</a>
  </div>
{/if}
