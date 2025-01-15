defmodule LiveSveltePheonixWeb.SessionLive do
  use LiveSveltePheonixWeb, :live_view
  use LiveSvelte.Components

  alias LiveSveltePheonix.Repo
  alias LiveSveltePheonix.Session

  @default_editor_content "<h2>lorem ipsum dolor</h2> <p>amet...</p>"

  def render(assigns) do
    ~H"""
    <main class="container p-2 rounded-md mx-auto bg-neutral-100 mb-4">
      <h1 class="text-center text-base-200">session_id: {@session_id}</h1>
      <.Editor socket={@socket} content={@content} session_id={@session_id} />
    </main>
    """
  end

  def mount(%{"session_id" => session_id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(LiveSveltePheonix.PubSub, "session:#{session_id}")
    end

    session = Repo.get_by(Session, session_id: session_id)

    {:ok,
     socket
     |> assign(:session_id, session_id)
     |> assign(:content, session.content || @default_editor_content)}
  end

  @spec handle_event(<<_::120>>, map(), map()) :: {:noreply, map()}
  def handle_event("content_updated", %{"content" => content}, socket) do
    session_id = socket.assigns.session_id

    session_id |> Session.update_content(content)

    Phoenix.PubSub.broadcast_from(
      LiveSveltePheonix.PubSub,
      self(),
      "session:#{session_id}",
      {:content_updated, content}
      ) # <- sand, except for de sandler, broadcast to all subscribers

    {:noreply, assign(socket, :content, content)}
  end

  def handle_info({:content_updated, content}, socket) do
    {:noreply, push_event(socket, "remote_content_updated", %{content: content})}
  end
end
