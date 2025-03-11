<script>
  export let user_sessions

  const tableHeaders = ['', 'Title', 'Session id', 'Updated at']
</script>

<div class="overflow-x-auto">
  {#if !user_sessions.length}
    {#each [1, 2, 3, 4, 5] as _skeleton}
      <div class="skeleton h-8 mt-4 w-full"></div>
    {/each}
  {:else}
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
  {/if}
</div>
