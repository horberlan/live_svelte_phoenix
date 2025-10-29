defmodule LiveSveltePheonixWeb.SessionLive do
  @moduledoc """
  LiveView for managing collaborative editing sessions.
  Handles real-time content updates and user invitations.
  """
  use LiveSveltePheonixWeb, :live_view
  use LiveSvelte.Components

  alias LiveSveltePheonix.Accounts
  alias LiveSveltePheonix.Repo
  alias LiveSveltePheonix.Session

  @default_editor_content "<h2>Start writing...</h2><p>Your content here</p>"
  @pubsub LiveSveltePheonix.PubSub

  def render(assigns) do
    ~H"""
    <main class="container p-2 rounded-md mx-auto bg-base-200 mb-4">
      <h1 class="text-center text-base-300 text-sm sm:text-base md:text-lg break-all px-2">
        Session: {@session_id}
      </h1>
      <.Editor socket={@socket} content={@content} docId={@session_id} enableCollaboration={true} />
      <.svelte name="invite/InviteUser" socket={@socket} />
    </main>
    """
  end

  def mount(%{"session_id" => session_id}, session_data, socket) do
    if connected?(socket) do
      subscribe_to_session_updates(session_id)
    end

    session = get_or_create_session(session_id, session_data)
    content = get_session_content(session)

    {:ok,
     socket
     |> assign(:session_id, session_id)
     |> assign(:page_title, "Note #{session_id}")
     |> assign(:content, content)}
  end

  def handle_event("content_updated", %{"content" => new_content}, socket) do
    session_id = socket.assigns.session_id

    update_session_content(session_id, new_content)
    broadcast_content_update(session_id, new_content)

    {:noreply, assign(socket, :content, new_content)}
  end

  def handle_event("invite_user", %{"email" => email}, socket) do
    session_id = socket.assigns.session_id

    Session.update_shared_users(session_id, email)

    {:noreply, put_flash(socket, :info, "Invitation sent to #{email}")}
  end

  def handle_info({:content_updated, content}, socket) do
    {:noreply, push_event(socket, "remote_content_updated", %{content: content})}
  end

  # Private Functions

  defp subscribe_to_session_updates(session_id) do
    Phoenix.PubSub.subscribe(@pubsub, session_topic(session_id))
  end

  defp get_or_create_session(session_id, session_data) do
    case Repo.get_by(Session, session_id: session_id) do
      nil -> create_new_session(session_id, session_data)
      existing_session -> existing_session
    end
  end

  defp create_new_session(session_id, session_data) do
    current_user = get_current_user(session_data)

    %Session{}
    |> Session.changeset(%{
      session_id: session_id,
      content: @default_editor_content,
      user_id: current_user && current_user.id
    })
    |> Repo.insert!()
  end

  defp get_current_user(session_data) do
    with user_token when not is_nil(user_token) <- session_data["user_token"],
         user when not is_nil(user) <- Accounts.get_user_by_session_token(user_token) do
      user
    else
      _ -> nil
    end
  end

  defp get_session_content(session) do
    session.content || @default_editor_content
  end

  defp update_session_content(session_id, content) do
    Session.update_content(session_id, content)
  end

  defp broadcast_content_update(session_id, content) do
    Phoenix.PubSub.broadcast_from(
      @pubsub,
      self(),
      session_topic(session_id),
      {:content_updated, content}
    )
  end

  defp session_topic(session_id), do: "session:#{session_id}"
end
