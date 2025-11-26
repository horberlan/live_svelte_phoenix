defmodule LiveSveltePheonix.Drawing do
  @moduledoc """
  Context for managing drawing strokes in collaborative sessions.

  This module provides functions to create, retrieve, and delete drawing strokes
  that are associated with collaborative sessions.

  ## Performance Optimizations

  The `drawing_strokes` table has the following indexes for optimal query performance:
  - `drawing_strokes_session_id_index` on `session_id` - Used for filtering by session
  - `drawing_strokes_inserted_at_index` on `inserted_at` - Used for ordering strokes

  These indexes ensure that:
  - `list_strokes_by_session/2` queries are fast even with many strokes
  - `count_strokes_by_session/1` uses index-only scans
  - `delete_strokes_by_session/1` efficiently locates strokes to delete

  For sessions with more than 500 strokes, consider using pagination via the
  `:limit` and `:offset` options in `list_strokes_by_session/2`.
  """

  import Ecto.Query
  alias LiveSveltePheonix.Repo
  alias LiveSveltePheonix.Drawing.Stroke

  @doc """
  Creates a new drawing stroke.

  ## Parameters

    - attrs: A map containing stroke attributes:
      - session_id (required): The session this stroke belongs to
      - path_data (required): SVG path data (e.g., "M10,10 L20,20")
      - color (required): Hex color code (e.g., "#3B82F6")
      - stroke_width (optional): Width of the stroke (default: 2.0)
      - user_id (optional): ID of the user who created the stroke

  ## Returns

    - {:ok, %Stroke{}} on success
    - {:error, %Ecto.Changeset{}} on validation failure
    - {:error, :database_error} on database failure

  ## Examples

      iex> create_stroke(%{session_id: "abc-123", path_data: "M10,10 L20,20", color: "#000000"})
      {:ok, %Stroke{}}

      iex> create_stroke(%{session_id: "abc-123", path_data: "", color: "invalid"})
      {:error, %Ecto.Changeset{}}
  """
  def create_stroke(attrs) do
    IO.puts("[Drawing] create_stroke called with attrs:")
    IO.inspect(attrs, label: "  attrs")

    try do
      changeset = %Stroke{}
      |> Stroke.changeset(attrs)

      IO.puts("[Drawing] Changeset valid?: #{changeset.valid?}")
      if not changeset.valid? do
        IO.inspect(changeset.errors, label: "  Changeset errors")
      end

      result = Repo.insert(changeset)

      case result do
        {:ok, stroke} ->
          IO.puts("[Drawing] Stroke created successfully with id: #{stroke.id}")
          result
        {:error, changeset} ->
          IO.puts("[Drawing] Failed to create stroke")
          IO.inspect(changeset.errors, label: "  Errors")
          result
      end
    rescue
      e in Ecto.QueryError ->
        require Logger
        Logger.error("Database error creating stroke: #{inspect(e)}, attrs: #{inspect(attrs)}")
        {:error, :database_error}

      e ->
        require Logger
        Logger.error("Unexpected error creating stroke: #{inspect(e)}, attrs: #{inspect(attrs)}")
        {:error, :unexpected_error}
    end
  end

  @doc """
  Lists all strokes for a given session, ordered by creation time.

  Strokes are returned in the order they were created (ascending by inserted_at)
  to preserve the drawing sequence.

  ## Parameters

    - session_id: The session ID to retrieve strokes for
    - opts: Optional keyword list with:
      - :limit - Maximum number of strokes to return (default: nil, returns all)
      - :offset - Number of strokes to skip (default: 0)

  ## Returns

    - {:ok, list} where list is a list of %Stroke{} structs, ordered by insertion time
    - {:error, :database_error} on database failure

  ## Examples

      iex> list_strokes_by_session("abc-123")
      {:ok, [%Stroke{}, %Stroke{}, ...]}

      iex> list_strokes_by_session("abc-123", limit: 100, offset: 0)
      {:ok, [%Stroke{}, ...]}
  """
  def list_strokes_by_session(session_id, opts \\ []) do
    try do
      limit = Keyword.get(opts, :limit)
      offset = Keyword.get(opts, :offset, 0)

      query = Stroke
      |> where([s], s.session_id == ^session_id)
      |> order_by([s], asc: s.inserted_at)

      query = if limit, do: limit(query, ^limit), else: query
      query = if offset > 0, do: offset(query, ^offset), else: query

      strokes = Repo.all(query)

      {:ok, strokes}
    rescue
      e in Ecto.QueryError ->
        require Logger
        Logger.error("Database error listing strokes for session #{session_id}: #{inspect(e)}")
        {:error, :database_error}

      e ->
        require Logger
        Logger.error("Unexpected error listing strokes for session #{session_id}: #{inspect(e)}")
        {:error, :unexpected_error}
    end
  end

  @doc """
  Deletes all strokes for a given session.

  This is typically used when clearing the canvas or deleting a session.

  ## Parameters

    - session_id: The session ID to delete strokes for

  ## Returns

    - {:ok, count} where count is the number of deleted strokes
    - {:error, :database_error} on database failure

  ## Examples

      iex> delete_strokes_by_session("abc-123")
      {:ok, 5}
  """
  def delete_strokes_by_session(session_id) do
    try do
      {count, _} = Stroke
      |> where([s], s.session_id == ^session_id)
      |> Repo.delete_all()

      {:ok, count}
    rescue
      e in Ecto.QueryError ->
        require Logger
        Logger.error("Database error deleting strokes for session #{session_id}: #{inspect(e)}")
        {:error, :database_error}

      e ->
        require Logger
        Logger.error("Unexpected error deleting strokes for session #{session_id}: #{inspect(e)}")
        {:error, :unexpected_error}
    end
  end

  @doc """
  Counts strokes for a session.

  Useful for implementing limits on the number of strokes per session.

  ## Parameters

    - session_id: The session ID to count strokes for

  ## Returns

    - {:ok, count} where count is an integer count of strokes
    - {:error, :database_error} on database failure

  ## Examples

      iex> count_strokes_by_session("abc-123")
      {:ok, 42}
  """
  def count_strokes_by_session(session_id) do
    try do
      count = Stroke
      |> where([s], s.session_id == ^session_id)
      |> Repo.aggregate(:count)

      {:ok, count}
    rescue
      e in Ecto.QueryError ->
        require Logger
        Logger.error("Database error counting strokes for session #{session_id}: #{inspect(e)}")
        {:error, :database_error}

      e ->
        require Logger
        Logger.error("Unexpected error counting strokes for session #{session_id}: #{inspect(e)}")
        {:error, :unexpected_error}
    end
  end

  @doc """
  Checks if a session has a large number of strokes that would benefit from pagination.

  ## Parameters

    - session_id: The session ID to check
    - threshold: The threshold above which pagination is recommended (default: 500)

  ## Returns

    - {:ok, boolean} where true indicates pagination should be used
    - {:error, reason} on failure

  ## Examples

      iex> should_paginate?("abc-123")
      {:ok, false}

      iex> should_paginate?("abc-123", 100)
      {:ok, true}
  """
  def should_paginate?(session_id, threshold \\ 500) do
    case count_strokes_by_session(session_id) do
      {:ok, count} -> {:ok, count > threshold}
      error -> error
    end
  end
end
