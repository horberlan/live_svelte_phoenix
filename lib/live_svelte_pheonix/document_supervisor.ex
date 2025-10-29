defmodule LiveSveltePheonix.DocumentSupervisor do
  @moduledoc """
  DynamicSupervisor to manage collaborative document processes.
  """
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a new document process or returns the existing one.
  """
  def start_document(doc_id, opts \\ []) do
    spec = {LiveSveltePheonix.CollaborativeDocument, Keyword.put(opts, :doc_id, doc_id)}

    case DynamicSupervisor.start_child(__MODULE__, spec) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      error -> error
    end
  end

  @doc """
  Stops a document process.
  """
  def stop_document(doc_id) do
    case Registry.lookup(LiveSveltePheonix.DocumentRegistry, doc_id) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] -> {:error, :not_found}
    end
  end
end
