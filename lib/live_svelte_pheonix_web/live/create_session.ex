defmodule LiveSveltePheonixWeb.CreateSession do
  use LiveSveltePheonixWeb, :live_view
  use LiveSvelte.Components
  alias LiveSveltePheonix.{Repo, Session}

  on_mount {LiveSveltePheonixWeb.UserAuth, :ensure_authenticated}

  def render(assigns) do
    ~H"""
    <.NewSession socket={@socket} current_user={@current_user} />
    """
  end

  def handle_event("new_session", _params, %{assigns: %{current_user: user}} = socket) do
    session_id = :crypto.strong_rand_bytes(32) |> Base.encode32()

    case create_session(user, session_id) do
      {:ok, _} -> push_to_session(session_id, socket)
      {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to create session")}
    end
  end

  defp create_session(user, session_id) do
    Repo.transaction(fn ->
      session_changeset =
        %Session{
          user_id: user.id,
          session_id: session_id,
          content: nil,
          shared_users: []
        }
        |> Session.changeset(%{})

      case Repo.insert(session_changeset) do
        {:ok, session} ->
          user_changeset = Ecto.Changeset.change(user, active_session: session_id)

          case Repo.update(user_changeset) do
            {:ok, _user} -> session
            {:error, _changeset} -> Repo.rollback(:user_update_failed)
          end

        {:error, _changeset} ->
          Repo.rollback(:session_creation_failed)
      end
    end)
    |> case do
      {:ok, session} -> {:ok, session}
      {:error, reason} -> {:error, "Failed to create session: #{reason}"}
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
