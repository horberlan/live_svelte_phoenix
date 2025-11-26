defmodule LiveSveltePheonix.Drawing.RateLimiter do
  @moduledoc """
  Rate limiter for drawing operations using ETS.

  Implements per-session rate limiting for stroke creation and canvas clearing
  to prevent abuse and ensure system stability.
  """

  use GenServer
  require Logger

  @table_name :drawing_rate_limiter
  @cleanup_interval :timer.minutes(5)

  # Rate limits
  @stroke_limit 100  # strokes per minute
  @clear_limit 10    # clears per minute
  @window_ms 60_000  # 1 minute window

  ## Client API

  @doc """
  Starts the rate limiter GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Checks if a stroke operation is allowed for the given session.

  Returns {:ok, remaining} if allowed, {:error, :rate_limit_exceeded} if not.
  """
  def check_stroke_limit(session_id) do
    check_limit(session_id, :stroke, @stroke_limit)
  end

  @doc """
  Checks if a clear operation is allowed for the given session.

  Returns {:ok, remaining} if allowed, {:error, :rate_limit_exceeded} if not.
  """
  def check_clear_limit(session_id) do
    check_limit(session_id, :clear, @clear_limit)
  end

  @doc """
  Records a stroke operation for the given session.
  """
  def record_stroke(session_id) do
    record_operation(session_id, :stroke)
  end

  @doc """
  Records a clear operation for the given session.
  """
  def record_clear(session_id) do
    record_operation(session_id, :clear)
  end

  @doc """
  Gets the current count for a specific operation type.
  """
  def get_count(session_id, operation_type) do
    key = {session_id, operation_type}
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@table_name, key) do
      [{^key, timestamps}] ->
        # Filter out timestamps outside the window
        recent = Enum.filter(timestamps, fn ts -> now - ts < @window_ms end)
        length(recent)

      [] ->
        0
    end
  end

  ## Private Functions

  defp check_limit(session_id, operation_type, limit) do
    key = {session_id, operation_type}
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@table_name, key) do
      [{^key, timestamps}] ->
        # Filter out timestamps outside the window
        recent = Enum.filter(timestamps, fn ts -> now - ts < @window_ms end)

        if length(recent) < limit do
          {:ok, limit - length(recent) - 1}
        else
          {:error, :rate_limit_exceeded}
        end

      [] ->
        {:ok, limit - 1}
    end
  end

  defp record_operation(session_id, operation_type) do
    key = {session_id, operation_type}
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@table_name, key) do
      [{^key, timestamps}] ->
        # Filter out old timestamps and add new one
        recent = Enum.filter(timestamps, fn ts -> now - ts < @window_ms end)
        :ets.insert(@table_name, {key, [now | recent]})

      [] ->
        :ets.insert(@table_name, {key, [now]})
    end

    :ok
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    # Create ETS table for storing rate limit data
    :ets.new(@table_name, [:named_table, :public, :set])

    # Schedule periodic cleanup
    schedule_cleanup()

    Logger.info("Drawing rate limiter started")
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_old_entries()
    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp cleanup_old_entries do
    now = System.monotonic_time(:millisecond)

    # Iterate through all entries and remove old timestamps
    :ets.foldl(
      fn {key, timestamps}, acc ->
        recent = Enum.filter(timestamps, fn ts -> now - ts < @window_ms end)

        if recent == [] do
          :ets.delete(@table_name, key)
        else
          :ets.insert(@table_name, {key, recent})
        end

        acc
      end,
      nil,
      @table_name
    )

    Logger.debug("Cleaned up old rate limiter entries")
  end
end
