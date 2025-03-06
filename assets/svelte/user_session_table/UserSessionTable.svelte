<script>
  export let user_sessions

  const tableHeaders = ['', 'Title', 'Session id', 'updated at']
</script>

<div class="overflow-x-auto">
  <table class="table table-zebra">
    <thead>
      <tr>
        {#each tableHeaders as header, index}
          <th>{header}</th>
        {/each}
      </tr>
    </thead>
    <tbody>
      {#each user_sessions as session, index}
        <tr>
          <th>{index + 1}</th>
          <td>{session.title}</td>
          <td>
            <a
              href="/session/{session.session_id}"
              data-phx-link="redirect"
              data-phx-link-state="push"
              class="link"
            >
              {session.session_id}
            </a>
          </td>
          <td>
            <span>{session.updated_at}</span>
          </td>
        </tr>
      {/each}
    </tbody>
  </table>
</div>