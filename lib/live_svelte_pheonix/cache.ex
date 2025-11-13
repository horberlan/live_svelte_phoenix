defmodule LiveSveltePheonix.Cache do
  @moduledoc """
  ETS-based cache for frequently accessed data.
  
  Provides fast in-memory caching for:
  - User session lists
  - Session metadata (titles, shared users)
  - Document state snapshots
  """
  use GenServer

  require Logger

  @table_name :live_svelte_cache
  @session_list_ttl 60_000  # 1 minute
  @session_metadata_ttl 300_000  # 5 minutes

  # Public API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Get cached user sessions list.
  Returns nil if not cached or expired.
  """
  def get_user_sessions(user_email) do
    key = {:user_sessions, user_email}
    now = System.system_time(:millisecond)
    
    case :ets.lookup(@table_name, key) do
      [{^key, {value, expires_at}}] when expires_at > now ->
        value
      _ ->
        nil
    end
  end

  @doc """
  Cache user sessions list with TTL.
  """
  def put_user_sessions(user_email, sessions) do
    key = {:user_sessions, user_email}
    expires_at = System.system_time(:millisecond) + @session_list_ttl
    :ets.insert(@table_name, {key, {sessions, expires_at}})
    :ok
  end

  @doc """
  Get cached session metadata (title, shared_users, etc).
  """
  def get_session_metadata(session_id) do
    key = {:session_metadata, session_id}
    now = System.system_time(:millisecond)
    
    case :ets.lookup(@table_name, key) do
      [{^key, {value, expires_at}}] when expires_at > now ->
        value
      _ ->
        nil
    end
  end

  @doc """
  Cache session metadata with TTL.
  """
  def put_session_metadata(session_id, metadata) do
    key = {:session_metadata, session_id}
    expires_at = System.system_time(:millisecond) + @session_metadata_ttl
    :ets.insert(@table_name, {key, {metadata, expires_at}})
    :ok
  end

  @doc """
  Invalidate all cached data for a session.
  Called when session is updated.
  """
  def invalidate_session(session_id) do
    # Remove session metadata
    :ets.delete(@table_name, {:session_metadata, session_id})
    
    # Invalidate all user session lists (they may contain this session)
    :ets.select_delete(@table_name, [
      {{:"$1", :_}, [{:==, {:element, 1, :"$1"}, {:const, :user_sessions}}], [true]}
    ])
    
    :ok
  end

  @doc """
  Invalidate cached user sessions for a specific user.
  """
  def invalidate_user_sessions(user_email) do
    :ets.delete(@table_name, {:user_sessions, user_email})
    :ok
  end

  @doc """
  Clear all cache entries.
  Useful for testing or manual cache reset.
  """
  def clear do
    :ets.delete_all_objects(@table_name)
    :ok
  end

  @doc """
  Get cache statistics.
  """
  def stats do
    size = :ets.info(@table_name, :size)
    memory = :ets.info(@table_name, :memory)
    
    %{
      size: size,
      memory_kb: memory * :erlang.system_info(:wordsize) / 1024
    }
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    table = :ets.new(@table_name, [
      :set,
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])

    # Schedule periodic cleanup of expired entries
    schedule_cleanup()

    {:ok, %{table: table}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired()
    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    # Cleanup every 5 minutes
    Process.send_after(self(), :cleanup, 5 * 60 * 1000)
  end

  defp cleanup_expired do
    now = System.system_time(:millisecond)
    
    :ets.select_delete(@table_name, [
      {{:_, {:"$1", :"$2"}}, [{:<, {:const, now}, :"$2"}], [true]}
    ])
  end
end

