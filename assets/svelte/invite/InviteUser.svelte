<script>
  export let live

  let email = ''

  function invite() {
    live.pushEvent('invite_user', { email })
    email = ''
  }
  let intl = {
    invite: 'Invite a member',
    placeholder: 'daisyui@daisyui.com',
  }
</script>

<div class="mt-4 pl-4">
  <input
    type="email"
    class="input input-bordered w-full max-w-xs"
    bind:value={email}
    placeholder={intl.placeholder}
  />
  <button class="btn" on:click={invite}>{intl.invite}</button>
</div>
