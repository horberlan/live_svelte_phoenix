<script>
  export let live;

  let intl = {
    btn_create: 'New note +',
  }
</script>

<button class="btn text-white" phx-click="new_session">{intl.btn_create}</button>
