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
  alias LiveSveltePheonixWeb.Presence
  alias StringIO

  @default_editor_content "<h2>Start writing...</h2><p>Your content here</p>"
  @pubsub LiveSveltePheonix.PubSub

  def render(assigns) do
    ~H"""
    <main class="container p-2 rounded-md mx-auto bg-base-200 mb-4">
      <div class="flex flex-wrap justify-between">
        <.svelte name="status/Session" socket={@socket} />
        <.svelte name="invite/InviteUser" socket={@socket} />
      </div>
      <div id={"session-wrapper-#{@session_id}"} class="relative" phx-hook="TrackClientCursor">
        <.Editor
          socket={@socket}
          content={@content}
          docId={@session_id}
          userId={@user_id}
          userName={@user_name}
          enableCollaboration={true}
        />

        <%= for user <- @users do %>
          <%= if user.socket_id != @socket_id do %>
            <div
              id={"cursor-#{user.socket_id}"}
              style={"position: absolute; left: #{user.x}%; top: #{user.y}%; transform: translate(-2px, -2px); transition: left 0.1s ease-out, top 0.1s ease-out;"}
              class="pointer-events-none z-10"
            >
              <svg class="size-4" fill="none" viewBox="0 0 31 32">
                <path
                  fill={"url(#gradient-#{user.socket_id})"}
                  d="m.609 10.86 5.234 15.488c1.793 5.306 8.344 7.175 12.666 3.612l9.497-7.826c4.424-3.646 3.69-10.625-1.396-13.27L11.88 1.2C5.488-2.124-1.697 4.033.609 10.859Z"
                />
                <defs>
                  <linearGradient
                    id={"gradient-#{user.socket_id}"}
                    x1="-4.982"
                    x2="23.447"
                    y1="-8.607"
                    y2="25.891"
                    gradientUnits="userSpaceOnUse"
                  >
                    <stop class="[stop-color:oklch(var(--p))]" />
                    <stop offset="1" class="[stop-color:oklch(var(--s))]" />
                  </linearGradient>
                </defs>
              </svg>
              <div class="mt-1.4 ml-2">
                <div class="bg-primary text-primary-content rounded-lg size-4 flex items-center justify-center">
                  <span class="text-xs">
                    {String.capitalize(String.first(user.username))}
                    <!-- String.slice(user.username, 1..-1//1) -->
                  </span>
                </div>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </main>
    """
  end

  def mount(%{"session_id" => session_id}, session_data, socket) do
    session = get_or_create_session(session_id, session_data)
    content = get_session_content(session)
    current_user = get_current_user(session_data)

    user_id =
      if current_user, do: "user-#{current_user.id}", else: "anonymous-#{:rand.uniform(1000)}"

    user_name = if current_user, do: current_user.email, else: user_id

    socket =
      socket
      |> assign(:session_id, session_id)
      |> assign(:page_title, "Note #{session_id}")
      |> assign(:content, content)
      |> assign(:socket_id, socket.id)
      |> assign(:user_id, user_id)
      |> assign(:user_name, user_name)
      |> assign(:users, [])

    if connected?(socket) do
      subscribe_to_session_updates(session_id)
      Phoenix.PubSub.subscribe(@pubsub, cursor_topic(session_id))

      {:ok, _} =
        Presence.track(self(), cursor_topic(session_id), socket.id, %{
          socket_id: socket.id,
          username: user_name,
          x: 50,
          y: 50,
          online_at: System.system_time(:second)
        })

      users = list_present_users(session_id)
      {:ok, assign(socket, :users, users)}
    else
      {:ok, socket}
    end
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

  def handle_event("cursor-move", %{"mouse_x" => x, "mouse_y" => y}, socket) do
    session_id = socket.assigns.session_id
    users = socket.assigns.users

    if length(users) > 1 do
      x_pos = parse_float(x)
      y_pos = parse_float(y)

      Presence.update(self(), cursor_topic(session_id), socket.id, fn meta ->
        Map.merge(meta, %{x: x_pos, y: y_pos})
      end)
    end

    {:noreply, socket}
  end

  def handle_info({:content_updated, content}, socket) do
    {:noreply, push_event(socket, "remote_content_updated", %{content: content})}
  end

  def handle_info(%{event: "presence_diff", payload: %{joins: _joins, leaves: leaves}}, socket) do
    users = list_present_users(socket.assigns.session_id)
    {:noreply, assign(socket, :users, users)}
  end

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
    Session.get_html_content(session, @default_editor_content)
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

  defp list_present_users(session_id) do
    Presence.list(cursor_topic(session_id))
    |> Enum.map(fn {_user_id, %{metas: [meta | _]}} -> meta end)
  end

  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float_val, _} -> float_val
      :error -> 0.0
    end
  end

  defp parse_float(value) when is_number(value), do: value / 1
  defp parse_float(_), do: 0.0

  defp session_topic(session_id), do: "session:#{session_id}"
  defp cursor_topic(session_id), do: "cursors:#{session_id}"
end
