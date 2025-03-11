defmodule LiveSveltePheonix.Session do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sessions" do
    field :session_id, :string
    field :content, :string
    field :shared_users, {:array, :string}
    belongs_to :user, LiveSveltePheonix.Accounts.User

    timestamps(type: :naive_datetime)
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:session_id, :content, :shared_users, :user_id])
    |> validate_required([:session_id, :user_id])
  end

  def update_content(session_id, content) do
    LiveSveltePheonix.Repo.get_by(__MODULE__, session_id: session_id)
    |> changeset(%{content: content})
    |> LiveSveltePheonix.Repo.update!()
  end

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
  only: [:id, :session_id, :content, :shared_users, :user_id, :inserted_at, :updated_at]
)
