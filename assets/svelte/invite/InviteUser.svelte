<script>
  export let live

  let email = ''
  let emailInput

  function handleSubmit(event) {
    event.preventDefault()
    if (emailInput.checkValidity()) {
      live.pushEvent('invite_user', { email })
      email = ''
    }
  }

  function checkEmailValidity() {
    if (emailInput.checkValidity()) {
      emailInput.classList.remove('input-error')
    } else {
      emailInput.classList.add('input-error')
    }
  }
  let intl = {
    invite: 'Invite a member',
    placeholder: 'mail@daisyui.com',
  }
</script>

<form class="flex gap-4" on:submit={handleSubmit}>
  <input
    type="email"
    class="input input-bordered input-sm"
    bind:value={email}
    placeholder={intl.placeholder}
    bind:this={emailInput}
    on:change={checkEmailValidity}
  />
  <button class="btn btn-secondary btn-sm" type="submit"> {intl.invite} </button>
</form>
