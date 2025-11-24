defmodule LiveSveltePheonixWeb.YjsChannel do
  @moduledoc """
  Phoenix Channel for Yjs CRDT synchronization.
  """
  use LiveSveltePheonixWeb, :channel
  require Logger

  alias LiveSveltePheonix.{CollaborativeDocument, DocumentSupervisor}

  @impl true
  def join("yjs:" <> doc_id, _params, socket) do
    Logger.info("[YjsChannel] Joining doc: #{doc_id}")

    # Start the document GenServer if not running
    {:ok, _pid} = DocumentSupervisor.start_document(doc_id)

    # Subscribe to updates
    CollaborativeDocument.subscribe(doc_id, self())

    # Get initial state
    case CollaborativeDocument.get_all(doc_id) do
      {:ok, %{doc: doc, awareness: awareness}} ->
        Logger.info("[YjsChannel] Sending initial state - doc size: #{byte_size(doc)}, awareness size: #{byte_size(awareness)}")
        socket = assign(socket, :doc_id, doc_id)
        {:ok, %{doc: doc, awareness: awareness}, socket}

      error ->
        Logger.error("[YjsChannel] Failed to get initial state: #{inspect(error)}")
        {:error, %{reason: "failed to load document"}}
    end
  end

  @impl true
  def handle_in("yjs_update", %{"payload" => payload}, socket) do
    doc_id = socket.assigns.doc_id
    Logger.debug("[YjsChannel] Received yjs_update for doc: #{doc_id}")

    with {:ok, update} <- Base.decode64(payload) do
      CollaborativeDocument.handle_update(doc_id, self(), update)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_in("awareness_update", %{"payload" => payload}, socket) do
    doc_id = socket.assigns.doc_id
    Logger.debug("[YjsChannel] Received awareness_update for doc: #{doc_id}")

    with {:ok, update} <- Base.decode64(payload) do
      CollaborativeDocument.handle_awareness_update(doc_id, self(), update)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({CollaborativeDocument, "yjs_update", payload}, socket) do
    Logger.debug("[YjsChannel] Broadcasting yjs_update to client")
    push(socket, "yjs_update", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info({CollaborativeDocument, "awareness_update", payload}, socket) do
    Logger.debug("[YjsChannel] Broadcasting awareness_update to client")
    push(socket, "awareness_update", payload)
    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    doc_id = socket.assigns[:doc_id]
    if doc_id do
      CollaborativeDocument.unsubscribe(doc_id, self())
    end
    :ok
  end
end
