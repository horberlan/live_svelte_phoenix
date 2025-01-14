defmodule LiveSveltePheonixWeb.SvelteLive do
  use LiveSveltePheonixWeb, :live_view
  use LiveSvelte.Components

  @default_editor_content "<h2>lorem ipsum dolor</h2> <p>amet...</p>"

  def render(assigns) do
    ~H"""
    <.Editor socket={@socket} content={@content} />
    """
  end

  def handle_event("content_updated", _value, socket) do
    socket.assigns.content |> IO.inspect(label: "content")
    {:noreply, assign(socket, :content, socket.assigns.content)}
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :number, 5) |> assign(:content, @default_editor_content)}

  end
end
