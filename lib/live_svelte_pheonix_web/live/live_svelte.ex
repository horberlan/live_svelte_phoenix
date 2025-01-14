defmodule LiveSveltePheonixWeb.SvelteLive do
  use LiveSveltePheonixWeb, :live_view
  use LiveSvelte.Components

  def render(assigns) do
    ~H"""
    <.NewSession socket={@socket} />
    """
  end

  def handle_event("new_session", _params, socket) do
    :crypto.strong_rand_bytes(32)
    |> Base.encode32()
    |> create_session()
    |> push_to_session(socket)
  end

  def create_session(session_id) do
    %{
      user_id: "user_id",
      session_id: session_id,
      content: nil
    }
    # make a call to DB

    session_id
  end

  def push_to_session(session_id, socket),
    do: {:noreply, push_navigate(socket, to: "/session/#{session_id}")}

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:created_session, nil)}
  end
end
