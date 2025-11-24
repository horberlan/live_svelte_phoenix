defmodule LiveSveltePheonix.CollaborativeDocument do
  @moduledoc """
  GenServer to manage collaborative documents in real-time using Yjs (y_ex).
  """
  use GenServer
  require Logger

  alias LiveSveltePheonix.Session

  @initial_state %{
    doc_id: nil,
    ydoc: nil,
    awareness: nil,
    subscribers: %{},
    last_updated: nil
  }

  # == Client API ==

  def start_link(opts) do
    doc_id = Keyword.fetch!(opts, :doc_id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(doc_id))
  end

  def stop(doc_id) do
    GenServer.stop(via_tuple(doc_id))
  end

  def subscribe(doc_id, pid) do
    GenServer.cast(via_tuple(doc_id), {:subscribe, pid})
  end

  def unsubscribe(doc_id, pid) do
    GenServer.cast(via_tuple(doc_id), {:unsubscribe, pid})
  end

  def get_all(doc_id) do
    GenServer.call(via_tuple(doc_id), :get_all)
  end

  def handle_update(doc_id, from, update) do
    GenServer.cast(via_tuple(doc_id), {:handle_update, from, update})
  end

  def handle_awareness_update(doc_id, from, update) do
    GenServer.cast(via_tuple(doc_id), {:handle_awareness_update, from, update})
  end

  # == GenServer Callbacks ==

  @impl true
  def init(opts) do
    doc_id = Keyword.fetch!(opts, :doc_id)

    # Initialize Yjs document
    ydoc = Yex.Doc.new()

    # Load persisted state if available
    ydoc_binary = Session.get_ydoc(doc_id)
    if ydoc_binary do
      Logger.info("Loading persisted state for #{doc_id}, size: #{byte_size(ydoc_binary)}")
      case Yex.apply_update(ydoc, ydoc_binary) do
        :ok ->
          Logger.info("Successfully loaded persisted state for #{doc_id}")
          :ok
        {:error, reason} ->
          Logger.warning("Failed to load persisted state: #{inspect(reason)}")
      end
    else
      Logger.info("No persisted state found for #{doc_id}")
    end

    # Initialize awareness
    {:ok, awareness} = Yex.Awareness.new(ydoc)

    state = %{
      @initial_state
      | doc_id: doc_id,
        ydoc: ydoc,
        awareness: awareness,
        last_updated: DateTime.utc_now()
    }

    Logger.info("CollaborativeDocument #{doc_id} started.")
    {:ok, state}
  end

  @impl true
  def handle_cast({:subscribe, pid}, state) do
    subscribers = Map.put(state.subscribers, pid, :ok)
    {:noreply, %{state | subscribers: subscribers}}
  end

  @impl true
  def handle_cast({:unsubscribe, pid}, state) do
    subscribers = Map.delete(state.subscribers, pid)
    {:noreply, %{state | subscribers: subscribers}}
  end

  @impl true
  def handle_cast({:handle_update, from, update}, state) do
    IO.puts("[CollaborativeDocument] Received update from #{inspect(from)}, size: #{byte_size(update)}")
    IO.puts("[CollaborativeDocument] Current subscribers: #{map_size(state.subscribers)}")

    case Yex.apply_update(state.ydoc, update) do
      :ok ->
        IO.puts("[CollaborativeDocument] Update applied successfully")

        # Persist the document state
        {:ok, encoded_state} = Yex.encode_state_as_update(state.ydoc)
        IO.puts("[CollaborativeDocument] Persisting state, size: #{byte_size(encoded_state)}")
        Session.update_ydoc(state.doc_id, encoded_state)
        IO.puts("[CollaborativeDocument] State persisted successfully")

        # Broadcast to other subscribers
        IO.puts("[CollaborativeDocument] Broadcasting to #{map_size(state.subscribers)} subscribers")
        broadcast(state.subscribers, from, "yjs_update", %{
          doc_id: state.doc_id,
          payload: Base.encode64(update)
        })

        {:noreply, %{state | last_updated: DateTime.utc_now()}}

      {:error, reason} ->
        Logger.error("Failed to apply update: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:handle_awareness_update, from, update}, state) do
    :ok = Yex.Awareness.apply_update(state.awareness, update)

    # Broadcast to other subscribers
    broadcast(state.subscribers, from, "awareness_update", %{
      doc_id: state.doc_id,
      payload: Base.encode64(update)
    })

    {:noreply, state}
  end

  @impl true
  def handle_call(:get_all, _from, state) do
    {:ok, doc_state} = Yex.encode_state_as_update(state.ydoc)
    {:ok, awareness_state} = Yex.Awareness.encode_update(state.awareness)

    Logger.info("[CollaborativeDocument] get_all called for #{state.doc_id}")
    Logger.info("[CollaborativeDocument] doc_state size: #{byte_size(doc_state)}")
    Logger.info("[CollaborativeDocument] awareness_state size: #{byte_size(awareness_state)}")

    reply = %{
      doc: Base.encode64(doc_state),
      awareness: Base.encode64(awareness_state)
    }

    {:reply, {:ok, reply}, state}
  end

  # == Private Helpers ==

  defp via_tuple(doc_id) do
    {:via, Registry, {LiveSveltePheonix.DocumentRegistry, doc_id}}
  end

  defp broadcast(subscribers, from, event, payload) do
    # Use Phoenix.PubSub for better reliability
    Phoenix.PubSub.broadcast_from(
      LiveSveltePheonix.PubSub,
      from,
      "document:#{payload.doc_id}",
      {__MODULE__, event, payload}
    )

    # Also send directly to subscribers as backup
    subscribers
    |> Map.keys()
    |> Enum.each(fn pid ->
      if pid != from do
        IO.puts("[CollaborativeDocument] Sending #{event} to #{inspect(pid)}")
        send(pid, {__MODULE__, event, payload})
      else
        IO.puts("[CollaborativeDocument] Skipping sender #{inspect(pid)}")
      end
    end)
  end
end
