defmodule LiveSveltePheonixWeb.CreateSession do
  use LiveSveltePheonixWeb, :live_view
  use LiveSvelte.Components

  alias LiveSveltePheonix.Repo
  alias LiveSveltePheonix.Session
  alias LiveSveltePheonix.User

  def render(assigns) do
    ~H"""
    <.NewSession socket={@socket} />
    """
  end

  def handle_event("new_session", _params, socket) do
    session_id = :crypto.strong_rand_bytes(32) |> Base.encode32()

    session_id
    |> create_session("user_id")
    |> push_to_session(socket)
  end

  def create_session(session_id, user_id) do
    with %User{} = user <- Repo.get_by(User, username: user_id) do
      {:ok, _session} = %Session{
          user_id: user.id,
          session_id: session_id,
          content: nil,
          shared_users: []
        }
        |> Session.changeset(%{
          user_id: user.id,
          session_id: session_id,
          content: nil,
          shared_users: []
        })
        |> Repo.insert()

      {:ok, _user} = user
        |> User.changeset(%{active_session: session_id})
        |> Repo.update()

      session_id
    else
      nil -> raise "User not found"
    end
  end

  def push_to_session(session_id, socket),
    do: {:noreply, push_navigate(socket, to: "/session/#{session_id}")}

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:created_session, nil)}
  end
end
