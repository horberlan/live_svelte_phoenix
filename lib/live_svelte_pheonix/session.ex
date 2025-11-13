defmodule LiveSveltePheonix.Session do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sessions" do
    field :session_id, :string
    field :content, :string
    field :shared_users, {:array, :string}

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
      :position
    ])
    |> validate_required([:session_id, :user_id])
  end

  def update_content(session_id, html_content) do
    with %__MODULE__{} = session <- LiveSveltePheonix.Repo.get_by(__MODULE__, session_id: session_id) do
      content_map =
        session.content
        |> normalize_content()
        |> Map.put("html", html_content)

      session
      |> changeset(%{content: Jason.encode!(content_map)})
      |> LiveSveltePheonix.Repo.update!()
    end
  end

  def update_delta_content(session_id, delta_content) do
    with %__MODULE__{} = session <- LiveSveltePheonix.Repo.get_by(__MODULE__, session_id: session_id) do
      content_map =
        session.content
        |> normalize_content()
        |> Map.put("delta", delta_content)

      session
      |> changeset(%{content: Jason.encode!(content_map)})
      |> LiveSveltePheonix.Repo.update()
    end
  end

  def get_html_content(%__MODULE__{} = session, default \\ nil) do
    session.content
    |> normalize_content()
    |> Map.get("html", default)
  end

  def get_delta_content(%__MODULE__{} = session) do
    session.content
    |> normalize_content()
    |> Map.get("delta")
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
