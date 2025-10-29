defmodule LiveSveltePheonixWeb.DocumentChannel do
  @moduledoc """
  Phoenix Channel for real-time document collaboration.
  Manages change synchronization using Delta OT.
  """
  use LiveSveltePheonixWeb, :channel

  alias LiveSveltePheonix.{CollaborativeDocument, DocumentSupervisor}
  alias LiveSveltePheonixWeb.Presence

  @impl true
  def join("document:" <> doc_id, %{"user_id" => user_id, "user_name" => user_name}, socket) do
    # Start or get the document process
    {:ok, _pid} = DocumentSupervisor.start_document(doc_id)

    # Add the collaborator
    CollaborativeDocument.add_collaborator(doc_id, user_id, %{
      name: user_name,
      cursor_position: nil,
      joined_at: DateTime.utc_now()
    })

    # Get the current document state
    state = CollaborativeDocument.get_state(doc_id)

    # Assign information to socket
    socket =
      socket
      |> assign(:doc_id, doc_id)
      |> assign(:user_id, user_id)
      |> assign(:user_name, user_name)

    # Track user presence
    send(self(), :after_join)

    {:ok, state, socket}
  end

  @impl true
  def join("document:" <> _doc_id, _params, _socket) do
    {:error, %{reason: "unauthorized"}}
  end

  @impl true
  def handle_in("update", %{"change" => change, "version" => client_version}, socket) do
    doc_id = socket.assigns.doc_id
    user_id = socket.assigns.user_id

    case CollaborativeDocument.update(doc_id, change, client_version, user_id) do
      {:ok, result} ->
        broadcast_from!(socket, "remote_update", %{
          change: result.change,
          version: result.version,
          user_id: user_id,
          user_name: socket.assigns.user_name
        })

        {:reply, {:ok, result}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  @impl true
  def handle_in("cursor_update", %{"position" => position}, socket) do
    doc_id = socket.assigns.doc_id
    user_id = socket.assigns.user_id

    CollaborativeDocument.update_cursor(doc_id, user_id, position)

    broadcast_from!(socket, "remote_cursor", %{
      user_id: user_id,
      user_name: socket.assigns.user_name,
      position: position
    })

    {:noreply, socket}
  end

  @impl true
  def handle_in("get_history", _params, socket) do
    doc_id = socket.assigns.doc_id
    history = CollaborativeDocument.get_history(doc_id)

    {:reply, {:ok, %{history: history}}, socket}
  end

  @impl true
  def handle_in("undo", _params, socket) do
    doc_id = socket.assigns.doc_id

    case CollaborativeDocument.undo(doc_id) do
      {:ok, contents} ->
        state = CollaborativeDocument.get_state(doc_id)

        broadcast!(socket, "document_updated", %{
          contents: contents,
          version: state.version,
          user_id: socket.assigns.user_id
        })

        {:reply, {:ok, %{contents: contents, version: state.version}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    user_id = socket.assigns.user_id
    user_name = socket.assigns.user_name

    # Track presence - track/4 needs (socket, key, meta)
    # The process PID is used automatically
    {:ok, _} = Presence.track(self(), socket.topic, user_id, %{
      user_id: user_id,
      user_name: user_name,
      online_at: inspect(System.system_time(:second))
    })

    # Send current presence list
    push(socket, "presence_state", Presence.list(socket))

    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    doc_id = socket.assigns[:doc_id]
    user_id = socket.assigns[:user_id]

    if doc_id && user_id do
      CollaborativeDocument.remove_collaborator(doc_id, user_id)
    end

    :ok
  end

end
