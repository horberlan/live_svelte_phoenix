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
    placeholder: 'daisyui@daisyui.com',
  }
</script>

<form class="mt-4 pl-4" on:submit={handleSubmit}>
  <input
    type="email"
    class="input input-border w-full max-w-xs"
    bind:value={email}
    placeholder={intl.placeholder}
    bind:this={emailInput}
    on:change={checkEmailValidity}
  />
  <button class="btn btn-secondary" type="submit"> {intl.invite} </button>
</form>
