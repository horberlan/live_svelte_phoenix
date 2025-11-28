defmodule LiveSveltePheonixWeb.CreateSession do
  use LiveSveltePheonixWeb, :live_view
  use LiveSvelte.Components

  alias LiveSveltePheonix.{Repo, Session, Cache}
  import Ecto.Query

  on_mount {LiveSveltePheonixWeb.UserAuth, :ensure_authenticated}

  def render(assigns) do
    ~H"""
    <!--
      <.svelte name="NewSession" socket={@socket} props={%{current_user: @current_user}}>
      </.svelte>
    -->
      <.svelte
        name="user_session_table/UserSessionTable"
        socket={@socket}
        props={%{user_sessions: @user_sessions}}
      />
    """
  end

  def handle_event("update_session_order", %{"session_ids" => session_ids}, %{assigns: %{current_user: user}} = socket) do
    Repo.transaction(fn ->
      Enum.with_index(session_ids, fn session_id, position ->
        query =
          from s in Session,
            where: s.session_id == ^session_id

        Repo.update_all(query, set: [position: position])
      end)
    end)

    # Invalidate cache after reordering
    Cache.invalidate_user_sessions(user.email)
    new_user_sessions = user_sessions(user.email)
    {:noreply, assign(socket, :user_sessions, new_user_sessions)}
  end

  def handle_event("create_session_with_content", %{"content" => content, "mode" => mode}, %{assigns: %{current_user: user}} = socket) do
    with :ok <- validate_content(content),
         :ok <- validate_mode(mode),
         session_id <- generate_session_id(),
         sanitized_content <- sanitize_content(content),
         {:ok, _session} <- create_session(user, session_id, sanitized_content, mode) do
      Cache.invalidate_user_sessions(user.email)
      navigate_to_session(socket, session_id, mode)
    else
      {:error, :invalid_content} ->
        {:noreply, put_flash(socket, :error, "Invalid content")}
      {:error, :content_too_large} ->
        {:noreply, put_flash(socket, :error, "Content is too large")}
      {:error, :invalid_mode} ->
        {:noreply, put_flash(socket, :error, "Invalid mode")}
      {:error, reason} ->
        require Logger
        Logger.error("Failed to create session: #{inspect(reason)}")
        {:noreply, put_flash(socket, :error, "Failed to create session. Please try again.")}
    end
  end

   def handle_event("new_session_from_editor", _params, %{assigns: %{current_user: user, content_editor: content}} = socket) do
    session_id = :crypto.strong_rand_bytes(32) |> Base.encode32() # This event handler seems to be unused now, but we'll fix it anyway.

    case create_session(user, session_id, content) do
      {:ok, _} ->
        # Invalidate cache after creating new session
        Cache.invalidate_user_sessions(user.email)
        push_to_session(session_id, socket)
      {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to create session")}
    end
  end

  def handle_event("new_session", _params, %{assigns: %{current_user: user}} = socket) do
    session_id = :crypto.strong_rand_bytes(32) |> Base.encode32()

    case create_session(user, session_id) do
      {:ok, _} ->
        # Invalidate cache after creating new session
        Cache.invalidate_user_sessions(user.email)
        push_to_session(session_id, socket)
      {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to create session")}
    end
  end

  defp create_session(user, session_id, content_editor, mode \\ "text") do
    Repo.transaction(fn ->
      max_pos_query = from(s in Session, where: s.user_id == ^user.id, select: max(s.position))
      current_max_pos = Repo.one(max_pos_query) || -1
      new_position = current_max_pos + 1

      attrs = %{
          user_id: user.id,
          session_id: session_id,
          content: content_editor,
          position: new_position,
          mode: mode
        }

      session_changeset = %Session{} |> Session.changeset(attrs)
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

  # Delegate create_session/2 to create_session/4 with default values
  defp create_session(user, session_id), do: create_session(user, session_id, nil, "text")

  # Validation helpers
  defp validate_content(content) when is_binary(content) do
    cond do
      String.trim(content) == "" -> {:error, :invalid_content}
      byte_size(content) > 1_000_000 -> {:error, :content_too_large}
      true -> :ok
    end
  end
  defp validate_content(_), do: :ok  # Allow nil for drawing mode

  defp validate_mode(mode) when mode in ["text", "drawing"], do: :ok
  defp validate_mode(_), do: {:error, :invalid_mode}

  defp generate_session_id do
    :crypto.strong_rand_bytes(32) |> Base.encode32()
  end

  defp sanitize_content(nil), do: nil
  defp sanitize_content(content) when is_binary(content) do
    # Basic HTML sanitization - remove script tags and dangerous attributes
    content
    |> String.replace(~r/<script[^>]*>.*?<\/script>/is, "")
    |> String.replace(~r/on\w+\s*=\s*["'][^"']*["']/i, "")
  end

  defp navigate_to_session(socket, session_id, "drawing") do
    {:noreply, push_navigate(socket, to: "/session/#{session_id}?drawing=true")}
  end
  defp navigate_to_session(socket, session_id, _mode) do
    {:noreply, push_navigate(socket, to: "/session/#{session_id}")}
  end

  def user_sessions(user_email) do
    # Try cache first
    case Cache.get_user_sessions(user_email) do
      nil ->
        # Cache miss - fetch from DB and cache
        sessions = fetch_user_sessions_from_db(user_email)
        Cache.put_user_sessions(user_email, sessions)
        sessions

      cached_sessions ->
        cached_sessions
    end
  end

  defp fetch_user_sessions_from_db(user_email) do
    import Ecto.Query

    case Repo.get_by(LiveSveltePheonix.Accounts.User, email: user_email) do
      nil ->
        []

      user ->
        query =
          from s in Session,
            where: s.user_id == ^user.id or fragment("? = ANY(shared_users)", ^user_email),
            order_by: [asc: s.position, asc: s.inserted_at]

        Repo.all(query)
        |> Enum.map(&format_sessions_table/1)
    end
  end

  defp format_sessions_table(session) do
    {:ok, updated_at} = LiveSveltePheonix.Utils.huminize_date(session.updated_at)

    html_content = if session.ydoc && byte_size(session.ydoc) > 0 do
      doc = Yex.Doc.new()
      :ok = Yex.apply_update(doc, session.ydoc)
      xml_fragment = Yex.Doc.get_xml_fragment(doc, "default")

      # Converter XmlFragment para string
      # O y_ex deve retornar UTF-8 válido
      xml_string = Yex.XmlFragment.to_string(xml_fragment)

      # Verificar se a string é UTF-8 válida
      if String.valid?(xml_string) do
        xml_string
      else
        # Se não for válida, tentar corrigir apenas uma vez
        case :unicode.characters_to_binary(xml_string, :latin1, :utf8) do
          result when is_binary(result) and result != xml_string -> result
          _ -> xml_string
        end
      end
    else
      Session.get_html_content(session, "")
    end

    session_title = case LiveSveltePheonix.Utils.parse_first_tag_text(html_content) do
      {:ok, children} ->
        Floki.text(children)
        |> String.trim()
        |> String.slice(0, 120)
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
