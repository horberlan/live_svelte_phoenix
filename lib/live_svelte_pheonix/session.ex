defmodule LiveSveltePheonix.Session do
  use Ecto.Schema
  import Ecto.Changeset

  alias LiveSveltePheonix.Cache

  schema "sessions" do
    field :session_id, :string
    field :content, :string
    field :shared_users, {:array, :string}
    field :ydoc, :binary
    field :background_color, :string

    # ADICIONADO: Campo para salvar a ordem
    field :position, :integer, default: 0

    belongs_to :user, LiveSveltePheonix.Accounts.User

    timestamps(type: :naive_datetime)
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :session_id,
      :content,
      :shared_users,
      :user_id,
      :position,
      :ydoc,
      :background_color
    ])
    |> validate_required([:session_id, :user_id])
  end

  def get_ydoc(session_id) do
    case LiveSveltePheonix.Repo.get_by(__MODULE__, session_id: session_id) do
      nil -> nil
      %__MODULE__{} = session -> session.ydoc
    end
  end

  def update_ydoc(session_id, ydoc_binary) do
    with %__MODULE__{} = session <- LiveSveltePheonix.Repo.get_by(__MODULE__, session_id: session_id) do
      session
      |> changeset(%{ydoc: ydoc_binary})
      |> LiveSveltePheonix.Repo.update()
    end
  end

  def update_background_color(session_id, color) do
    require Logger
    Logger.info("[Session] Updating background color for #{session_id} to #{color}")

    case LiveSveltePheonix.Repo.get_by(__MODULE__, session_id: session_id) do
      nil ->
        Logger.warning("[Session] Session not found: #{session_id}")
        {:error, :not_found}

      %__MODULE__{} = session ->
        result = session
        |> changeset(%{background_color: color})
        |> LiveSveltePheonix.Repo.update()

        case result do
          {:ok, updated_session} ->
            Logger.info("[Session] Background color updated successfully")
            {:ok, updated_session}

          {:error, changeset} ->
            Logger.error("[Session] Failed to update: #{inspect(changeset.errors)}")
            {:error, changeset}
        end
    end
  end

  def get_background_color(session_id) do
    case LiveSveltePheonix.Repo.get_by(__MODULE__, session_id: session_id) do
      nil -> nil
      %__MODULE__{} = session -> session.background_color
    end
  end

  def update_content(session_id, html_content) do
    with %__MODULE__{} = session <- LiveSveltePheonix.Repo.get_by(__MODULE__, session_id: session_id) do
      content_map =
        session.content
        |> normalize_content()
        |> Map.put("html", html_content)

      result =
        session
        |> changeset(%{content: Jason.encode!(content_map)})
        |> LiveSveltePheonix.Repo.update!()

      # Invalidate cache after update
      Cache.invalidate_session(session_id)
      result
    end
  end

  def get_html_content(%__MODULE__{} = session, default \\ "") do
    session.content
    |> normalize_content()
    |> Map.get("html", default)
  end



  defp normalize_content(nil), do: %{}
  defp normalize_content(""), do: %{}

  defp normalize_content(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, map} when is_map(map) -> map
      _ -> %{"html" => content}
    end
  end

  defp normalize_content(content) when is_map(content), do: content

  def update_shared_users(session_id, user_email) do
    this_session = LiveSveltePheonix.Repo.get_by(__MODULE__, session_id: session_id)
    updated_shared_users = (this_session.shared_users || []) ++ [user_email]

    this_session
    |> changeset(%{shared_users: updated_shared_users})
    |> LiveSveltePheonix.Repo.update!()
  end
end

require Protocol

Protocol.derive(
  Jason.Encoder,
  LiveSveltePheonix.Session,
  only: [
    :id,
    :session_id,
    :content,
    :shared_users,
    :user_id,
    :inserted_at,
    :updated_at,
    :position # ADICIONADO: Para que o campo seja serializado em JSON
  ]
)
