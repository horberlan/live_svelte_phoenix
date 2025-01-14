defmodule LiveSveltePheonixWeb.SvelteLive do
  use LiveSveltePheonixWeb, :live_view
  use LiveSvelte.Components

  def render(assigns) do
    ~H"""
    <.Editor number={@number} socket={@socket} />
    """
  end

  def handle_event("content_updated", %{"content" => content}, socket) do
    {:noreply, assign(socket, :content, content)}
  end

  @spec mount(any(), any(), map()) :: {:ok, map()}
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :number, 5) |> assign(:content, "")}
  end
end
