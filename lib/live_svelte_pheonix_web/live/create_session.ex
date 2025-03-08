defmodule LiveSveltePheonixWeb.CreateSession do
  use LiveSveltePheonixWeb, :live_view
  use LiveSvelte.Components

  alias LiveSveltePheonix.{Repo, Session}
  import Ecto.Query

  on_mount {LiveSveltePheonixWeb.UserAuth, :ensure_authenticated}

  def render(assigns) do
    ~H"""
    <.svelte name="NewSession" socket={@socket} props={%{current_user: @current_user}}>
      <.svelte
        name="user_session_table/UserSessionTable"
        socket={@socket}
        props={%{user_sessions: @user_sessions}}
      />
    </.svelte>
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

  def user_sessions(user_email) do
    import Ecto.Query

    case Repo.get_by(LiveSveltePheonix.Accounts.User, email: user_email) do
      nil ->
        []

      user ->
        query =
          from s in Session,
            where: s.user_id == ^user.id or fragment("? = ANY(shared_users)", ^user_email)

        Repo.all(query)
        |> Enum.map(&format_sessions_table/1)
    end
  end

  defp format_sessions_table(session) do
    {:ok, updated_at} = LiveSveltePheonix.Utils.huminize_date(session.updated_at)

    session_title =
      case LiveSveltePheonix.Utils.parse_first_tag_text(session.content) do
        {:ok, children} -> Floki.text(children)
        _ -> ""
      end

    %{
      session_id: session.session_id,
      title: session_title,
      shared_users: session.shared_users,
      updated_at: updated_at
    }
  end

  def push_to_session(session_id, socket),
    do: {:noreply, push_navigate(socket, to: "/session/#{session_id}")}

  def mount(params, session, socket) do
    case connected?(socket) do
      true -> connected_mount(params, session, socket)
      false -> {:ok, socket |> assign(:user_sessions, [])}
    end
  end

  def connected_mount(_params, _session, socket) do
    user_sessions = user_sessions(socket.assigns.current_user.email)

    {:ok,
     socket
     |> assign(:created_session, nil)
     |> assign(:user_sessions, user_sessions)}
  end
end
