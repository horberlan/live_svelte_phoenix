defmodule LiveSveltePheonix.Workers.DocumentSnapshotWorker do
  @moduledoc """
  Periodically persists collaborative document snapshots using Oban.

  Jobs ensure we keep durable copies of the latest delta and HTML without
  blocking the write path.
  """

  use Oban.Worker,
    queue: :document_snapshots,
    max_attempts: 5,
    unique: [fields: [:args, :worker], keys: [:doc_id, :target_version], period: 60]

  require Logger

  alias LiveSveltePheonix.{CollaborativeDocument, DocumentSupervisor, Session}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"doc_id" => doc_id} = args}) do
    target_version = Map.get(args, "target_version")

    with :ok <- ensure_document_started(doc_id),
         state when is_map(state) <- CollaborativeDocument.get_state(doc_id) do
      maybe_persist(state, target_version)
    else
      {:error, reason} ->
        Logger.warning(
          "DocumentSnapshotWorker failed to ensure document #{inspect(doc_id)}: #{inspect(reason)}"
        )

        {:error, reason}

      _ ->
        Logger.warning(
          "DocumentSnapshotWorker could not load state for document #{inspect(doc_id)}"
        )

        :discard
    end
  end

  defp ensure_document_started(doc_id) do
    case DocumentSupervisor.start_document(doc_id) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp maybe_persist(state, target_version) do
    doc_id = state.doc_id

    cond do
      is_integer(target_version) and state.version < target_version ->
        Logger.info(
          "Skipping snapshot for document #{doc_id}: state version #{state.version} behind target #{target_version}"
        )

        {:snooze, 5}

      true ->
        with :ok <- persist_delta(doc_id, state.contents),
             :ok <- persist_html(doc_id, state.html) do
          :ok
        end
    end
  end

  defp persist_delta(_doc_id, nil), do: :ok
  defp persist_delta(_doc_id, []), do: :ok

  defp persist_delta(doc_id, contents) do
    case Session.update_delta_content(doc_id, contents) do
      {:ok, _session} -> :ok
      nil -> :ok
      {:error, changeset} ->
        Logger.warning(
          "DocumentSnapshotWorker could not persist delta for #{doc_id}: #{inspect(changeset.errors)}"
        )

        {:error, :delta_persist_failed}
    end
  end

  defp persist_html(_doc_id, nil), do: :ok

  defp persist_html(doc_id, html) when is_binary(html) and html != "" do
    case Session.update_content(doc_id, html) do
      nil -> :ok
      _ -> :ok
    end
  rescue
    exception ->
      Logger.warning(
        "DocumentSnapshotWorker could not persist html for #{doc_id}: #{Exception.message(exception)}"
      )

      {:error, :html_persist_failed}
  end

  defp persist_html(_doc_id, _), do: :ok
end


