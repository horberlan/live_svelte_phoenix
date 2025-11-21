<script>
  export let live

  let email = ''
  let emailInput

  function handleSubmit(event) {
    
    event.preventDefault()
    if (!email.length) {
      emailInput.classList.add('input-error')
      return
    }
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
    placeholder: 'email@daisyui.com',
  }
</script>

<form class="flex flex-wrap gap-2" on:submit={handleSubmit}>
  <input
    type="email"
    class="input input-bordered input-xs"
    bind:value={email}
    placeholder={intl.placeholder}
    bind:this={emailInput}
    on:change={checkEmailValidity}
  />

  <button class="btn btn-secondary btn-xs" type="submit">
    <span class="text-secondary-content">
      <svg
        class="size-4 ![color:inherit]"
        fill="currentColor"
        viewBox="0 0 24 24"
      >
        <path
          d="M8.5,3.25 C10.847,3.25 12.75,5.153 12.75,7.5 C12.75,9.847 10.847,11.75 8.5,11.75 C6.153,11.75 4.25,9.847 4.25,7.5 C4.25,5.153 6.153,3.25 8.5,3.25 Z M1.25,18.286 C1.25,15.449 3.722,13.25 6.643,13.25 L10.357,13.25 C11.556,13.25 12.669,13.616 13.57,14.241 C13.911,14.476 13.995,14.944 13.759,15.284 C13.523,15.625 13.056,15.709 12.715,15.473 C12.064,15.022 11.249,14.75 10.357,14.75 L6.643,14.75 C4.435,14.75 2.75,16.388 2.75,18.286 C2.75,18.763 3.188,19.25 3.857,19.25 L13.143,19.25 C13.557,19.25 13.893,19.586 13.893,20 C13.893,20.414 13.557,20.75 13.143,20.75 L3.857,20.75 C2.475,20.75 1.25,19.702 1.25,18.286 Z M5.75,7.5 C5.75,9.019 6.981,10.25 8.5,10.25 C10.019,10.25 11.25,9.019 11.25,7.5 C11.25,5.981 10.019,4.75 8.5,4.75 C6.981,4.75 5.75,5.981 5.75,7.5 Z M19.75,14 L19.75,16.25 L22,16.25 C22.414,16.25 22.75,16.586 22.75,17 C22.75,17.414 22.414,17.75 22,17.75 L19.75,17.75 L19.75,20 C19.75,20.414 19.414,20.75 19,20.75 C18.586,20.75 18.25,20.414 18.25,20 L18.25,17.75 L16,17.75 C15.586,17.75 15.25,17.414 15.25,17 C15.25,16.586 15.586,16.25 16,16.25 L18.25,16.25 L18.25,14 C18.25,13.586 18.586,13.25 19,13.25 C19.414,13.25 19.75,13.586 19.75,14 Z M13.5,3.25 C15.847,3.25 17.75,5.153 17.75,7.5 C17.75,9.847 15.847,11.75 13.5,11.75 C13.086,11.75 12.75,11.414 12.75,11 C12.75,10.586 13.086,10.25 13.5,10.25 C15.019,10.25 16.25,9.019 16.25,7.5 C16.25,5.981 15.019,4.75 13.5,4.75 C13.086,4.75 12.75,4.414 12.75,4 C12.75,3.586 13.086,3.25 13.5,3.25 Z"
        />
      </svg>
    </span>
  </button>
</form>
