defmodule LiveSveltePheonix.CollaborativeDocument do
  @moduledoc """
  GenServer to manage collaborative documents in real-time using Delta OT.
  Supports multiple collaborators with automatic conflict resolution.
  """
  use GenServer

  @initial_state %{
    # Number of changes made to the document
    version: 0,
    # Delta updated with all applied changes
    contents: [],
    # Inverted versions of all changes (for undo/history)
    inverted_changes: [],
    # Normal changes (for redo/history)
    changes: [],
    # Connected collaborators {user_id => %{name, cursor_position}}
    collaborators: %{},
    # Timestamp of last update
    last_updated: nil
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
  def update(doc_id, change, client_version, user_id) do
    GenServer.call(via_tuple(doc_id), {:update, change, client_version, user_id})
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
    initial_content = Keyword.get(opts, :initial_content, [])

    state = %{
      @initial_state
      | contents: initial_content,
        last_updated: DateTime.utc_now()
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:update, change, client_version, user_id}, _from, state) do
    # If the change is a full update (TipTap JSON)
    new_contents =
      if is_map(change) && Map.get(change, "type") == "full_update" do
        change
      else
        # Fallback to deltas (compatibility)
        transformed_change =
          if client_version < state.version do
            changes_since = Enum.take(state.changes, state.version - client_version)

            Enum.reduce(changes_since, change, fn server_change, client_change ->
              Delta.transform(client_change, server_change, false)
            end)
          else
            change
          end

        _inverted = Delta.invert(transformed_change, state.contents)
        Delta.compose(state.contents, transformed_change)
      end

    new_state = %{
      state
      | version: state.version + 1,
        contents: new_contents,
        inverted_changes:
          if(is_map(change) && Map.get(change, "type") == "full_update",
            do: state.inverted_changes,
            else: [change | state.inverted_changes]
          ),
        changes: [change | state.changes],
        last_updated: DateTime.utc_now()
    }

    result = %{
      version: new_state.version,
      contents: new_contents,
      change: change,
      user_id: user_id
    }

    {:reply, {:ok, result}, new_state}
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
      last_updated: state.last_updated
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
end
