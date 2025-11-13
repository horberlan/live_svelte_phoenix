defmodule LiveSveltePheonix.CollaborativeDocument do
  @moduledoc """
  GenServer to manage collaborative documents in real-time using Delta OT.
  Supports multiple collaborators with automatic conflict resolution.
  """
  use GenServer

  require Logger

  alias Oban
  alias LiveSveltePheonix.Repo
  alias LiveSveltePheonix.Session
  alias LiveSveltePheonix.Workers.DocumentSnapshotWorker

  @snapshot_delta_threshold 50

  @initial_state %{
    # Document identifier
    doc_id: nil,
    # Number of changes made to the document
    version: 0,
    # Quill-style Delta document content
    contents: [],
    # Inverted versions of all changes (for undo/history)
    inverted_changes: [],
    # Normal changes (for redo/history)
    changes: [],
    # Connected collaborators {user_id => %{name, cursor_position}}
    collaborators: %{},
    # Timestamp of last update
    last_updated: nil,
    # Cached HTML snapshot
    html: nil,
    # Changes since the last background snapshot
    changes_since_snapshot: 0
  }

  def start_link(opts) do
    doc_id = Keyword.fetch!(opts, :doc_id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(doc_id))
  end

  def stop(doc_id) do
    GenServer.stop(via_tuple(doc_id))
  end

  @doc """
  Applies a change to the document and returns the new state.
  Accepts the client version to detect conflicts.
  """
  def update(doc_id, change, client_version, user_id, html_snapshot \\ nil) do
    GenServer.call(via_tuple(doc_id), {:update, change, client_version, user_id, html_snapshot})
  end

  @doc """
  Returns the current document content
  """
  def get_contents(doc_id) do
    GenServer.call(via_tuple(doc_id), :get_contents)
  end

  @doc """
  Returns the complete document state including version and collaborators
  """
  def get_state(doc_id) do
    GenServer.call(via_tuple(doc_id), :get_state)
  end

  @doc """
  Returns the document history
  """
  def get_history(doc_id) do
    GenServer.call(via_tuple(doc_id), :get_history)
  end

  @doc """
  Undoes the last change
  """
  def undo(doc_id) do
    GenServer.call(via_tuple(doc_id), :undo)
  end

  @doc """
  Redoes the last undone change
  """
  def redo(doc_id) do
    GenServer.call(via_tuple(doc_id), :redo)
  end

  @doc """
  Adds a collaborator to the document
  """
  def add_collaborator(doc_id, user_id, user_info) do
    GenServer.cast(via_tuple(doc_id), {:add_collaborator, user_id, user_info})
  end

  @doc """
  Removes a collaborator from the document
  """
  def remove_collaborator(doc_id, user_id) do
    GenServer.cast(via_tuple(doc_id), {:remove_collaborator, user_id})
  end

  @doc """
  Updates a collaborator's cursor position
  """
  def update_cursor(doc_id, user_id, cursor_position) do
    GenServer.cast(via_tuple(doc_id), {:update_cursor, user_id, cursor_position})
  end

  @impl true
  def init(opts) do
    doc_id = Keyword.fetch!(opts, :doc_id)

    loaded_content = load_content_from_db(doc_id)
    loaded_html = load_html_from_db(doc_id)

    state = %{
      @initial_state
      | doc_id: doc_id,
        contents: loaded_content,
        html: loaded_html,
        last_updated: DateTime.utc_now()
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:update, change, client_version, user_id, html_snapshot}, _from, state) do
    IO.inspect({:incoming_change_to_document, change}, label: "CollaborativeDocument")

    # Validate and normalize the incoming change
    normalized_change = normalize_delta(change)

    # Reject empty or invalid deltas
    if empty_delta?(normalized_change) do
      Logger.warning("Received empty or invalid delta from user #{user_id}")
      {:reply, {:error, :invalid_delta}, state}
    else
      transformed_change =
        if client_version < state.version do
          changes_since =
            Enum.take(state.changes, state.version - client_version)
            |> Enum.reverse()

          Enum.reduce(changes_since, normalized_change, fn server_change, client_change ->
            Delta.transform(client_change, server_change, false)
          end)
        else
          normalized_change
        end

      IO.inspect({:transformed_change_in_document, transformed_change}, label: "CollaborativeDocument")

      # Validate that transformed change is still valid
      if empty_delta?(transformed_change) do
        Logger.warning("Transformed delta is empty for user #{user_id}")
        {:reply, {:error, :invalid_transformed_delta}, state}
      else
        inverted = Delta.invert(transformed_change, state.contents)
        composed_contents = Delta.compose(state.contents, transformed_change)

        # Validate composed contents - ensure it's a valid list
        normalized_contents = normalize_delta(composed_contents)

        # Only update HTML if a new snapshot is provided
        # Don't keep old HTML as it may be out of sync with delta
        new_html = if is_binary(html_snapshot) and html_snapshot != "", do: html_snapshot, else: nil

        new_state =
          %{
          state
          | version: state.version + 1,
            contents: normalized_contents,
            inverted_changes: [inverted | state.inverted_changes],
            changes: [transformed_change | Enum.take(state.changes, 99)],
            last_updated: DateTime.utc_now(),
            html: new_html,
            changes_since_snapshot: state.changes_since_snapshot + 1
          }
          |> maybe_enqueue_snapshot()

        persist_contents(new_state.doc_id, normalized_contents)
        # Only persist HTML if we have a fresh snapshot
        # This ensures HTML is always in sync with delta
        persist_html(new_state.doc_id, new_html)

        result = %{
          version: new_state.version,
          change: transformed_change, # Broadcast the transformed change
          user_id: user_id,
          contents: normalized_contents,
          html: new_html
        }

        {:reply, {:ok, result}, new_state}
      end
    end
  end

  @impl true
  def handle_call(:get_contents, _from, state) do
    {:reply, state.contents, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    result = %{
      version: state.version,
      contents: state.contents,
      collaborators: state.collaborators,
      last_updated: state.last_updated,
      html: state.html
    }

    {:reply, result, state}
  end

  @impl true
  def handle_call(:get_history, _from, state) do
    current = {state.version, state.contents}

    history =
      Enum.scan(state.inverted_changes, current, fn inverted, {version, contents} ->
        contents = Delta.compose(contents, inverted)
        {version - 1, contents}
      end)

    {:reply, [current | history], state}
  end

  @impl true
  def handle_call(:undo, _from, %{version: 0} = state) do
    {:reply, {:error, :nothing_to_undo}, state}
  end

  @impl true
  def handle_call(:undo, _from, state) do
    [last_change | remaining_inverted] = state.inverted_changes
    [_last_normal | remaining_changes] = state.changes

    new_contents = Delta.compose(state.contents, last_change)

    new_state = %{
      state
      | version: state.version - 1,
        contents: new_contents,
        inverted_changes: remaining_inverted,
        changes: remaining_changes,
        last_updated: DateTime.utc_now()
    }

    {:reply, {:ok, new_contents}, new_state}
  end

  @impl true
  def handle_call(:redo, _from, state) do
    # Simplified implementation - can be expanded
    {:reply, {:error, :not_implemented}, state}
  end

  @impl true
  def handle_cast({:add_collaborator, user_id, user_info}, state) do
    collaborators = Map.put(state.collaborators, user_id, user_info)
    {:noreply, %{state | collaborators: collaborators}}
  end

  @impl true
  def handle_cast({:remove_collaborator, user_id}, state) do
    collaborators = Map.delete(state.collaborators, user_id)
    {:noreply, %{state | collaborators: collaborators}}
  end

  @impl true
  def handle_cast({:update_cursor, user_id, cursor_position}, state) do
    collaborators =
      Map.update(state.collaborators, user_id, %{cursor_position: cursor_position}, fn info ->
        Map.put(info, :cursor_position, cursor_position)
      end)

    {:noreply, %{state | collaborators: collaborators}}
  end

  defp via_tuple(doc_id) do
    {:via, Registry, {LiveSveltePheonix.DocumentRegistry, doc_id}}
  end

  defp load_content_from_db(doc_id) do
    case Repo.get_by(Session, session_id: doc_id) do
      nil ->
        []

      %Session{} = session ->
        case Session.get_delta_content(session) do
          nil -> []
          delta -> normalize_delta(delta)
        end
    end
  end

  defp load_html_from_db(doc_id) do
    case Repo.get_by(Session, session_id: doc_id) do
      nil -> nil
      %Session{} = session -> Session.get_html_content(session)
    end
  end

  defp maybe_enqueue_snapshot(%{doc_id: nil} = state), do: state

  defp maybe_enqueue_snapshot(%{changes_since_snapshot: changes} = state)
       when changes < @snapshot_delta_threshold,
       do: state

  defp maybe_enqueue_snapshot(%{doc_id: doc_id} = state) do
    if oban_disabled?() do
      %{state | changes_since_snapshot: 0}
    else
      job =
        DocumentSnapshotWorker.new(%{
          "doc_id" => doc_id,
          "target_version" => state.version
        })

      case Oban.insert(job) do
        {:ok, _job} ->
          :ok

        {:error, :conflict} ->
          :ok

        {:error, reason} ->
          Logger.warning(
            "Failed to enqueue snapshot job for #{inspect(doc_id)}: #{inspect(reason)}"
          )
      end

      %{state | changes_since_snapshot: 0}
    end
  rescue
    exception ->
      Logger.warning(
        "Unexpected error enqueuing snapshot job for #{inspect(doc_id)}: #{Exception.message(exception)}"
      )

      state
  end

  defp persist_contents(nil, _contents), do: :ok

  defp persist_contents(doc_id, contents) do
    # Persist asynchronously? For now we perform it inline so the latest
    # state is durable before acknowledging the client.
    Session.update_delta_content(doc_id, contents)
  end

  defp persist_html(_doc_id, nil), do: :ok

  defp persist_html(doc_id, html) when is_binary(html) and html != "" do
    Session.update_content(doc_id, html)
    :ok
  end

  defp persist_html(_doc_id, _), do: :ok

  defp oban_disabled? do
    oban_config = Application.get_env(:live_svelte_pheonix, Oban, [])

    Keyword.get(oban_config, :queues) == false or
      Keyword.get(oban_config, :testing) == :manual
  end

  # Normalize delta to ensure it's a valid list format
  defp normalize_delta(nil), do: []
  defp normalize_delta([]), do: []
  defp normalize_delta(delta) when is_list(delta), do: delta
  defp normalize_delta(delta) when is_map(delta), do: [delta]
  defp normalize_delta(_invalid), do: []

  # Check if delta is empty (only retains or no meaningful operations)
  defp empty_delta?(nil), do: true
  defp empty_delta?([]), do: true
  defp empty_delta?(delta) when is_list(delta) do
    Enum.all?(delta, fn op ->
      case op do
        %{"retain" => _} -> true
        %{retain: _} -> true
        _ -> false
      end
    end)
  end
  defp empty_delta?(_), do: false
end
