defmodule LiveSveltePheonixWeb.SessionLive do
  use LiveSveltePheonixWeb, :live_view
  use LiveSvelte.Components

  @default_editor_content "<h2>lorem ipsum dolor</h2> <p>amet...</p>"

  def render(assigns) do
    ~H"""
    <main class="container mx-auto">
      <h1>Session: {@session_id}</h1>
      <.Editor socket={@socket} content={@content} />
    </main>
    """
  end

  def mount(%{"session_id" => session_id}, _session, socket) do
    # if connected?(socket) do
    {:ok,
     socket
     |> assign(:session_id, session_id)
     |> assign(:content, @default_editor_content)}

    # end
  end

  def handle_event("content_updated", %{"content" => content}, socket) do
    {:noreply, assign(socket, :content, content)}
  end
end
