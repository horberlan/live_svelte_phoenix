defmodule LiveSveltePheonixWeb.SessionLive do
  @moduledoc """
  LiveView for managing collaborative editing sessions using Yjs.
  """
  use LiveSveltePheonixWeb, :live_view
  use LiveSvelte.Components

  alias LiveSveltePheonix.Accounts
  alias LiveSveltePheonix.Repo
  alias LiveSveltePheonix.Session
  alias LiveSveltePheonix.DocumentSupervisor
  alias LiveSveltePheonix.CollaborativeDocument
  alias LiveSveltePheonixWeb.Presence

  @pubsub LiveSveltePheonix.PubSub

  # --- Data Structures ---

  @impl true
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
          backgroundColor={@background_color}
        />
        <%= for user <- @users do %>
          <%= if user.socket_id != @socket_id do %>
            <div
              id={"cursor-#{user.socket_id}"}
              style={"position: absolute; left: #{user.x}%; top: #{user.y}%; transform: translate(-2px, -2px); transition: left 0.1s ease-out, top 0.1s ease-out;"}
              class="pointer-events-none z-10 opacity-[0.8]"
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

  @impl true
  def mount(%{"session_id" => session_id}, session_data, socket) do
    # Ensure the session exists in the database
    get_or_create_session(session_id, session_data)

    # Start the document GenServer if it's not already running
    DocumentSupervisor.start_document(session_id)

    # Subscribe this LiveView to the document's updates
    CollaborativeDocument.subscribe(session_id, self())

    current_user = get_current_user(session_data)
    user_id = if current_user, do: "user-#{current_user.id}", else: "anonymous-#{:rand.uniform(1000)}"
    user_name = if current_user, do: current_user.email, else: user_id

    # Load background color from database
    background_color = Session.get_background_color(session_id)

    socket =
      socket
      |> assign(:session_id, session_id)
      |> assign(:page_title, "Note #{session_id}")
      |> assign(:content, "") # Content is loaded by Yjs
      |> assign(:socket_id, socket.id)
      |> assign(:user_id, user_id)
      |> assign(:user_name, user_name)
      |> assign(:users, [])
      |> assign(:background_color, background_color)

    if connected?(socket) do
      # Subscribe to cursor updates
      Phoenix.PubSub.subscribe(@pubsub, cursor_topic(session_id))

      # Subscribe to session updates (background color, etc)
      Phoenix.PubSub.subscribe(@pubsub, "session:#{session_id}")

      # Track this user's presence
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

  @impl true
  def terminate(_reason, socket) do
    CollaborativeDocument.unsubscribe(socket.assigns.session_id, self())
    :ok
  end

  # --- Event Handling ---

  @impl true
  def handle_event("yjs_provider_ready", %{"doc_id" => doc_id}, socket) do
    IO.puts("[SessionLive] yjs_provider_ready for doc: #{doc_id}")
    case CollaborativeDocument.get_all(doc_id) do
      {:ok, %{doc: doc, awareness: awareness}} ->
        IO.puts("[SessionLive] Sending initial state, doc size: #{byte_size(doc)}, awareness size: #{byte_size(awareness)}")

        # Send the event
        socket = push_event(socket, "yjs_initial_state", %{
          status: "ok",
          doc: doc,
          awareness: awareness
        })

        IO.puts("[SessionLive] push_event called successfully")
        {:noreply, socket}

      error ->
        IO.puts("[SessionLive] Error getting initial state: #{inspect(error)}")
        {:noreply, push_event(socket, "yjs_initial_state", %{status: "error"})}
    end
  end

  @impl true
  def handle_event("yjs_update", %{"doc_id" => doc_id, "payload" => payload}, socket) do
    IO.puts("[SessionLive] Received yjs_update for doc: #{doc_id}, payload size: #{String.length(payload)}")
    with {:ok, update} <- Base.decode64(payload) do
      IO.puts("[SessionLive] Decoded update, size: #{byte_size(update)}, sending to CollaborativeDocument")
      CollaborativeDocument.handle_update(doc_id, self(), update)
    else
      error ->
        IO.puts("[SessionLive] Error decoding update: #{inspect(error)}")
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("awareness_update", %{"doc_id" => doc_id, "payload" => payload}, socket) do
    IO.puts("[SessionLive] Received awareness_update for doc: #{doc_id}")
    with {:ok, update} <- Base.decode64(payload) do
      CollaborativeDocument.handle_awareness_update(doc_id, self(), update)
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("invite_user", %{"email" => email}, socket) do
    session_id = socket.assigns.session_id
    Session.update_shared_users(session_id, email)
    {:noreply, put_flash(socket, :info, "Invitation sent to #{email}")}
  end

  @impl true
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

  @impl true
  def handle_event("background_color_changed", %{"color" => color}, socket) do
    session_id = socket.assigns.session_id
    IO.puts("[SessionLive] Received background_color_changed: #{color} for session: #{session_id}")

    case Session.update_background_color(session_id, color) do
      {:ok, _session} ->
        IO.puts("[SessionLive] Background color saved successfully")

        # Broadcast to other users in the same session
        Phoenix.PubSub.broadcast_from(
          @pubsub,
          self(),
          "session:#{session_id}",
          {:background_color_changed, color}
        )

        {:noreply, assign(socket, :background_color, color)}

      error ->
        IO.puts("[SessionLive] Error saving background color: #{inspect(error)}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({CollaborativeDocument, "yjs_update", payload}, socket) do
    IO.puts("[SessionLive] Broadcasting yjs_update to client, doc: #{payload.doc_id}")
    push_event(socket, "yjs_update", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info({CollaborativeDocument, "awareness_update", payload}, socket) do
    IO.puts("[SessionLive] Broadcasting awareness_update to client, doc: #{payload.doc_id}")
    push_event(socket, "awareness_update", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info(%{event: "presence_diff", payload: %{joins: _joins, leaves: _leaves}}, socket) do
    users = list_present_users(socket.assigns.session_id)
    {:noreply, assign(socket, :users, users)}
  end

  @impl true
  def handle_info({:background_color_changed, color}, socket) do
    IO.puts("[SessionLive] Broadcasting background color change to client: #{color}")
    {:noreply, push_event(socket, "background_color_updated", %{color: color})}
  end

  # --- Private Helpers ---

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

  defp cursor_topic(session_id), do: "cursors:#{session_id}"
end
