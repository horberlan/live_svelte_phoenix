defmodule LiveSveltePheonixWeb.SessionLive do
  use LiveSveltePheonixWeb, :live_view
  use LiveSvelte.Components

  alias LiveSveltePheonix.Repo
  alias LiveSveltePheonix.Session

  @default_editor_content "<h2>lorem ipsum dolor</h2> <p>amet...</p>"

  def render(assigns) do
    ~H"""
    <main class="container p-2 rounded-md mx-auto bg-secondary mb-4">
      <h1 class="text-center text-base-200">session_id: {@session_id}</h1>
      <.Editor socket={@socket} content={@content} version={@version} />
      <.svelte name="invite/InviteUser" socket={@socket} />
    </main>
    """
  end

  def mount(%{"session_id" => session_id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(LiveSveltePheonix.PubSub, "session:#{session_id}")
    end

    session =
      Repo.get_by(Session, session_id: session_id) ||
        %Session{session_id: session_id, content: @default_editor_content, version: 0}

    {:ok,
     socket
     |> assign(:session_id, session_id)
     |> assign(:page_title, "Note #{session_id}")
     |> assign(:content, session.content || @default_editor_content)
     |> assign(:version, session.version || 0)}
  end

  def handle_event(
        "content_updated",
        %{
          "old_content" => old_content,
          "new_content" => new_content,
          "version" => client_version
        },
        socket
      ) do
    current_version = socket.assigns.version
    current_content = socket.assigns.content

    {merged_content, new_version} =
      cond do
        client_version == current_version ->
          {new_content, current_version + 1}

        true ->
          diff =
            String.myers_difference(old_content, current_content)
            |> Enum.reject(fn {type, _} -> type == :eq end)

          merged = Enum.reduce(diff, new_content, &apply_diff/2)
          {merged, current_version + 1}
      end

    socket.assigns.session_id
    |> Session.update_content(merged_content, new_version)

    Phoenix.PubSub.broadcast_from(
      LiveSveltePheonix.PubSub,
      self(),
      "session:#{socket.assigns.session_id}",
      {:content_updated, merged_content, new_version}
    )

    {:noreply, socket |> assign(:content, merged_content) |> assign(:version, new_version)}
  end

  def handle_event("invite_user", %{"email" => email}, socket) do
    socket.assigns.session_id
    |> Session.update_shared_users(email)

    {:noreply, socket |> put_flash(:info, "An invitation has been sent to #{email}.")}
  end

  def handle_info({:content_updated, content, version}, socket) do
    if socket.assigns.content != content or socket.assigns.version != version do
      {:noreply,
       push_event(socket, "remote_content_updated", %{content: content, version: version})
       |> assign(:content, content)
       |> assign(:version, version)}
    else
      {:noreply, socket}
    end
  end

  defp apply_diff({:del, del}, acc), do: String.replace(acc, del, "", global: false)
  defp apply_diff({:ins, ins}, acc), do: acc <> ins
  defp apply_diff(_, acc), do: acc
end
