defmodule LiveSveltePheonixWeb.SvelteLive do
  use LiveSveltePheonixWeb, :live_view
  use LiveSvelte.Components

  def render(assigns) do
    ~H"""
    <.Editor number={@number} socket={@socket} content={@content} />
    """
  end

  def handle_event("content_updated", %{"content" => content}, socket) do
    IO.inspect(content, label: "content")
    {:noreply, assign(socket, :content, content)}
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :number, 5) |> assign(:content, "<h2>lorem ipsum dolor</h2> <p>amet...</p>")}
  end
end
