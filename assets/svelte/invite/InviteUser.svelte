<script>
  export let live

  let email = ''

  function invite() {
    live.pushEvent('invite_user', { email })
    email = ''
  }
</script>

<div class="mt-4">
  <input
    type="email"
    class="input input-bordered w-full max-w-xs"
    bind:value={email}
    placeholder="daisyui@daisyui.com"
  />
  <button class="btn" on:click={invite}>Convidar</button>
</div>
