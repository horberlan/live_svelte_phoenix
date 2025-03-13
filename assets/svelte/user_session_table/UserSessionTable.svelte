<script>
  export let user_sessions
  export let user_table_loading

  const tableIntl = {
    head: ['', 'Title', 'Session id', 'Updated at'],
    not_found: 'No sessions found',
  }
</script>

<div class="overflow-x-auto">
  {#if user_table_loading}
    {#each [1, 2, 3, 4, 5] as _skeleton}
      <div class="skeleton h-8 mt-4 w-full"></div>
    {/each}
  {:else if user_sessions.length === 0}
    <div class="text-center p-4 text-gray-500">
      {tableIntl.not_found}
    </div>
  {:else}
    <table class="table table-zebra">
      <thead>
        <tr>
          {#each tableIntl.head as header, index}
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
  {/if}
</div>
