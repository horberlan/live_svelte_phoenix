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
  alias LiveSveltePheonix.Drawing
  alias LiveSveltePheonixWeb.Presence

  @pubsub LiveSveltePheonix.PubSub

  @impl true
  def render(assigns) do
    IO.puts("[SessionLive] render called - strokes: #{length(assigns.drawing_strokes)}, version: #{assigns.drawing_strokes_version}, drawing_mode: #{assigns.drawing_mode}")
    ~H"""
    <main class="container p-2 rounded-md min-w-[100vw] bg-base-200 mb-4">
      <div class="flex flex-wrap justify-between">
        <.svelte name="status/Session" socket={@socket} />
        <.svelte name="invite/InviteUser" socket={@socket} />
      </div>

      <%= if @drawing_mode do %>
        <.svelte
          name="DrawingCanvas"
          socket={@socket}
          id={"drawing-canvas-#{@session_id}"}
        />
        <!-- Debug: strokes count = <%= length(@drawing_strokes) %>, version = <%= @drawing_strokes_version %> -->
      <% else %>
        <div id={"session-wrapper-#{@session_id}"} class="relative" phx-hook="TrackClientCursor">
          <.Editor
            socket={@socket}
            content={@content}
            docId={@session_id}
            userId={@user_id}
            userName={@user_name}
            enableCollaboration={true}
            backgroundColor={@background_color}
            drawingMode={@drawing_mode}
          />
          <%= for user <- @users do %>
            <%= if user.socket_id != @socket_id do %>
              <div
                id={"cursor-#{user.socket_id}"}
                style={"position: absolute; left: #{user.x}%; top: #{user.y}%; transform: translate(-2px, -2px); transition: left 0.1s ease-out, top 0.1s ease-out;"}
                class="pointer-events-none z-10 opacity-[0.8]"
              >
              <svg class="size-6" viewBox="0 0 353 352" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path fill={"url(#gradient-#{user.socket_id})"} d="M7.92098 39.7644C2.74077 20.4315 20.4315 2.74077 39.7643 7.92098L326.684 84.8007C350.513 91.1858 352.885 124.064 330.219 133.803L197.998 190.615C191.751 193.3 186.805 198.324 184.218 204.612L133.462 327.987C123.998 350.99 90.7404 348.851 84.3027 324.825L7.92098 39.7644Z" fill="#2163DE" stroke="white" stroke-width="14"/>
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
                <div class="ml-4">
                  <div class="bg-secondary text-secondary-content rounded-lg px-2 py-1 flex items-center justify-center">
                    <span class="text-xs">
                      <%=
                        [prefix | _] = String.split(user.username, "@")
                        String.capitalize(prefix)
                      %>
                    </span>
                  </div>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>
      <% end %>
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

    # Load existing strokes from database
    IO.puts("[SessionLive] ========== LOADING STROKES ==========")
    IO.puts("[SessionLive] Session ID: #{session_id}")

    strokes = case Drawing.list_strokes_by_session(session_id) do
      {:ok, strokes} ->
        IO.puts("[SessionLive] Loaded #{length(strokes)} strokes for session #{session_id}")

        # Convert Ecto structs to simple maps for Svelte
        serialized_strokes = Enum.map(strokes, fn stroke ->
          %{
            path_data: stroke.path_data,
            color: stroke.color,
            stroke_width: stroke.stroke_width
          }
        end)

        if length(serialized_strokes) > 0 do
          IO.puts("[SessionLive] First stroke preview:")
          IO.inspect(List.first(serialized_strokes), label: "  First stroke")
        end

        serialized_strokes
      {:error, reason} ->
        require Logger
        Logger.error("Failed to load strokes for session #{session_id}: #{inspect(reason)}")
        []
    end

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
      |> assign(:drawing_strokes, strokes)
      |> assign(:drawing_strokes_version, 0)
      |> assign(:drawing_mode, false)

    if connected?(socket) do
      # Subscribe to cursor updates
      Phoenix.PubSub.subscribe(@pubsub, cursor_topic(session_id))

      # Subscribe to session updates (background color, etc)
      Phoenix.PubSub.subscribe(@pubsub, "session:#{session_id}")

      # Subscribe to drawing events
      Phoenix.PubSub.subscribe(@pubsub, drawing_topic(session_id))

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
  def handle_event("stroke_drawn", params, socket) do
    session_id = socket.assigns.session_id
    user_id = socket.assigns.user_id

    path = Map.get(params, "path")
    color = Map.get(params, "color")
    stroke_width = Map.get(params, "stroke_width", 2.0)

    IO.puts("[SessionLive] Received stroke_drawn event - session: #{session_id}, path length: #{String.length(path)}, color: #{color}, width: #{stroke_width}")

    # Check rate limit
    case LiveSveltePheonix.Drawing.RateLimiter.check_stroke_limit(session_id) do
      {:ok, _remaining} ->
        # Record the operation
        LiveSveltePheonix.Drawing.RateLimiter.record_stroke(session_id)

        # Proceed with creating the stroke
        create_and_broadcast_stroke(socket, session_id, user_id, path, color, stroke_width)

      {:error, :rate_limit_exceeded} ->
        require Logger
        Logger.warning("Rate limit exceeded for stroke creation in session #{session_id}")

        {:noreply, put_flash(socket, :error, "Drawing too fast. Please slow down.")}
    end
  end

  @impl true
  def handle_event("clear_canvas", _params, socket) do
    session_id = socket.assigns.session_id
    IO.puts("[SessionLive] ========== CLEAR CANVAS EVENT ==========")
    IO.puts("[SessionLive] Session: #{session_id}")

    clear_and_broadcast(socket, session_id)
  end

  @impl true
  def handle_event("test_event", params, socket) do
    IO.puts("[SessionLive] ✅ TEST EVENT RECEIVED!")
    IO.inspect(params, label: "  Test params")
    {:noreply, socket}
  end

  @impl true
  def handle_event("undo_stroke", _params, socket) do
    session_id = socket.assigns.session_id
    IO.puts("[SessionLive] ========== UNDO STROKE EVENT ==========")
    IO.puts("[SessionLive] Session: #{session_id}")

    undo_and_broadcast(socket, session_id)
  end

  @impl true
  def handle_event("redo_stroke", %{"stroke" => stroke_data}, socket) do
    session_id = socket.assigns.session_id
    user_id = socket.assigns.user_id

    path = Map.get(stroke_data, "path_data")
    color = Map.get(stroke_data, "color")
    stroke_width = Map.get(stroke_data, "stroke_width", 2.0)

    IO.puts("[SessionLive] ========== REDO STROKE EVENT ==========")
    IO.puts("[SessionLive] Session: #{session_id}, restoring stroke")

    # Re-create the stroke in the database
    create_and_broadcast_stroke(socket, session_id, user_id, path, color, stroke_width)
  end

  @impl true
  def handle_event("redo_stroke", _params, socket) do
    # Fallback if no stroke data provided
    IO.puts("[SessionLive] Redo stroke event received without stroke data")
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_drawing_mode", _params, socket) do
    new_mode = !socket.assigns.drawing_mode
    current_strokes = socket.assigns.drawing_strokes
    current_version = socket.assigns.drawing_strokes_version

    # Always increment version when switching to drawing mode
    new_version = if new_mode, do: current_version + 1, else: current_version

    IO.puts("[SessionLive] ========== TOGGLE DRAWING MODE ==========")
    IO.puts("[SessionLive] Mode: #{socket.assigns.drawing_mode} -> #{new_mode}")
    IO.puts("[SessionLive] Strokes: #{length(current_strokes)}")
    IO.puts("[SessionLive] Version: #{current_version} -> #{new_version}")

    socket = socket
      |> assign(:drawing_mode, new_mode)
      |> assign(:drawing_strokes_version, new_version)

    # If switching to drawing mode and there are strokes, push them via event
    socket = if new_mode and length(current_strokes) > 0 do
      IO.puts("[SessionLive] Pushing #{length(current_strokes)} strokes via load_strokes event")
      push_event(socket, "load_strokes", %{
        strokes: current_strokes,
        version: new_version
      })
    else
      socket
    end

    {:noreply, socket}
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

  @impl true
  def handle_info({:new_stroke, stroke_data}, socket) do
    IO.puts("[SessionLive] Received :new_stroke broadcast")
    IO.inspect(stroke_data, label: "  Stroke data")

    # Update the strokes list in the socket assigns
    new_stroke = %{
      path_data: stroke_data.path,
      color: stroke_data.color,
      stroke_width: stroke_data.strokeWidth
    }

    updated_strokes = socket.assigns.drawing_strokes ++ [new_stroke]
    new_version = socket.assigns.drawing_strokes_version + 1

    IO.puts("[SessionLive] Updated strokes count: #{length(updated_strokes)}, version: #{new_version}")
    IO.puts("[SessionLive] Assigning updated strokes to socket - this should trigger re-render")

    # Only push event if in drawing mode (component is mounted)
    socket = if socket.assigns.drawing_mode do
      IO.puts("[SessionLive] In drawing mode, pushing new_stroke event to Svelte")
      push_event(socket, "new_stroke", %{
        path_data: stroke_data.path,
        color: stroke_data.color,
        stroke_width: stroke_data.strokeWidth
      })
    else
      IO.puts("[SessionLive] Not in drawing mode, skipping push_event")
      socket
    end

    # Assign the updated strokes with version - LiveView will detect the change and re-render
    {:noreply, socket
      |> assign(:drawing_strokes, updated_strokes)
      |> assign(:drawing_strokes_version, new_version)
    }
  end

  @impl true
  def handle_info({:clear_canvas, _session_id}, socket) do
    new_version = socket.assigns.drawing_strokes_version + 1
    IO.puts("[SessionLive] Clearing canvas, resetting strokes to empty list, version: #{new_version}")

    # Only push event if in drawing mode (component is mounted)
    socket = if socket.assigns.drawing_mode do
      IO.puts("[SessionLive] In drawing mode, pushing canvas_cleared event to Svelte")
      push_event(socket, "canvas_cleared", %{})
    else
      IO.puts("[SessionLive] Not in drawing mode, skipping push_event")
      socket
    end

    {:noreply, socket
      |> assign(:drawing_strokes, [])
      |> assign(:drawing_strokes_version, new_version)
    }
  end

  @impl true
  def handle_info({:stroke_undone, _session_id}, socket) do
    IO.puts("[SessionLive] Received :stroke_undone broadcast")

    # Update the strokes list (remove last)
    updated_strokes = socket.assigns.drawing_strokes |> Enum.drop(-1)
    new_version = socket.assigns.drawing_strokes_version + 1

    IO.puts("[SessionLive] Updated strokes count after undo: #{length(updated_strokes)}, version: #{new_version}")

    # Only push event if in drawing mode (component is mounted)
    socket = if socket.assigns.drawing_mode do
      IO.puts("[SessionLive] In drawing mode, pushing stroke_undone event to Svelte")
      push_event(socket, "stroke_undone", %{})
    else
      IO.puts("[SessionLive] Not in drawing mode, skipping push_event")
      socket
    end

    {:noreply, socket
      |> assign(:drawing_strokes, updated_strokes)
      |> assign(:drawing_strokes_version, new_version)
    }
  end

  defp create_and_broadcast_stroke(socket, session_id, user_id, path, color, stroke_width \\ 2.0) do
    IO.puts("[SessionLive] Creating stroke - session: #{session_id}, user: #{user_id}, width: #{stroke_width}")

    case Drawing.create_stroke(%{
      session_id: session_id,
      path_data: path,
      color: color,
      stroke_width: stroke_width,
      user_id: user_id
    }) do
      {:ok, stroke} ->
        IO.puts("[SessionLive] Stroke created successfully with id: #{stroke.id}")

        # Serialize the stroke for consistency
        serialized_stroke = %{
          path_data: stroke.path_data,
          color: stroke.color,
          stroke_width: stroke.stroke_width
        }

        # Update local strokes list with serialized data
        updated_strokes = socket.assigns.drawing_strokes ++ [serialized_stroke]
        new_version = socket.assigns.drawing_strokes_version + 1

        IO.puts("[SessionLive] Updating socket with #{length(updated_strokes)} strokes, version: #{new_version}")
        IO.inspect(serialized_stroke, label: "  New stroke")

        socket = socket
        |> assign(:drawing_strokes, updated_strokes)
        |> assign(:drawing_strokes_version, new_version)

        IO.puts("[SessionLive] Socket updated, strokes count: #{length(socket.assigns.drawing_strokes)}")

        # Broadcast stroke to other users in the session
        serialized_data = serialize_stroke(stroke)
        case Phoenix.PubSub.broadcast_from(
          @pubsub,
          self(),
          drawing_topic(session_id),
          {:new_stroke, serialized_data}
        ) do
          :ok ->
            IO.puts("[SessionLive] Stroke broadcast successfully to session #{session_id}")
          {:error, reason} ->
            require Logger
            Logger.error("Failed to broadcast stroke for session #{session_id}: #{inspect(reason)}")
        end

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        require Logger
        Logger.warning("Validation error creating stroke for session #{session_id}: #{inspect(changeset.errors)}")

        error_message = format_changeset_errors(changeset)

        {:noreply, put_flash(socket, :error, "Failed to save stroke: #{error_message}")}

      {:error, :database_error} ->
        require Logger
        Logger.error("Database error creating stroke for session #{session_id}")

        {:noreply, put_flash(socket, :error, "Database error. Please try again.")}

      {:error, reason} ->
        require Logger
        Logger.error("Unexpected error creating stroke for session #{session_id}: #{inspect(reason)}")

        {:noreply, put_flash(socket, :error, "An unexpected error occurred")}
    end
  end

  defp undo_and_broadcast(socket, session_id) do
    case Drawing.delete_last_stroke(session_id) do
      {:ok, nil} ->
        IO.puts("[SessionLive] No strokes to undo for session #{session_id}")
        {:noreply, socket}

      {:ok, _deleted_stroke} ->
        IO.puts("[SessionLive] Deleted last stroke from DB for session #{session_id}")

        # Update local strokes list (remove last)
        updated_strokes = socket.assigns.drawing_strokes |> Enum.drop(-1)
        new_version = socket.assigns.drawing_strokes_version + 1

        IO.puts("[SessionLive] Updated strokes count: #{length(updated_strokes)}, version: #{new_version}")

        # Note: Don't push event to origin client - they already updated locally before sending the event
        # Only broadcast to OTHER users in the session
        case Phoenix.PubSub.broadcast_from(
               @pubsub,
               self(),
               drawing_topic(session_id),
               {:stroke_undone, session_id}
             ) do
          :ok -> IO.puts("[SessionLive] Broadcasted stroke_undone to other participants")
          {:error, reason} ->
            require Logger
            Logger.error("Failed to broadcast undo event for session #{session_id}: #{inspect(reason)}")
        end

        {:noreply, socket
          |> assign(:drawing_strokes, updated_strokes)
          |> assign(:drawing_strokes_version, new_version)
        }

      {:error, reason} ->
        require Logger
        Logger.error("Failed to undo stroke for session #{session_id}: #{inspect(reason)}")
        {:noreply, put_flash(socket, :error, "Failed to undo. Please try again.")}
    end
  end

  defp clear_and_broadcast(socket, session_id) do
    case Drawing.delete_strokes_by_session(session_id) do
      {:ok, _count} ->
        IO.puts("[SessionLive] Deleted strokes from DB for session #{session_id}")

        # 1) push event directly to the origin LiveView -> ensures the origin client clears immediately
        socket = if socket.assigns.drawing_mode do
          IO.puts("[SessionLive] Pushing canvas_cleared to origin client")
          push_event(socket, "canvas_cleared", %{})
        else
          socket
        end

        # 2) broadcast to other LiveViews in the session (broadcast_from excludes origin)
        case Phoenix.PubSub.broadcast_from(
               @pubsub,
               self(),
               drawing_topic(session_id),
               {:clear_canvas, session_id}
             ) do
          :ok -> IO.puts("[SessionLive] Broadcasted clear_canvas to other participants")
          {:error, reason} ->
            require Logger
            Logger.error("Failed to broadcast clear event for session #{session_id}: #{inspect(reason)}")
        end

        new_version = socket.assigns.drawing_strokes_version + 1

        {:noreply, socket
          |> assign(:drawing_strokes, [])
          |> assign(:drawing_strokes_version, new_version)
        }

      {:error, reason} ->
        require Logger
        Logger.error("Failed to delete strokes for session #{session_id}: #{inspect(reason)}")
        {:noreply, put_flash(socket, :error, "Failed to clear canvas. Please try again.")}
    end
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

  defp drawing_topic(session_id), do: "drawing:#{session_id}"

  defp serialize_stroke(stroke) do
    %{
      path: stroke.path_data,
      color: stroke.color,
      strokeWidth: stroke.stroke_width
    }
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, errors} ->
      "#{field}: #{Enum.join(errors, ", ")}"
    end)
    |> Enum.join("; ")
  end
end
