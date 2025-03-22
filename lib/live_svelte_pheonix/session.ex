defmodule LiveSveltePheonix.Session do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sessions" do
    field :session_id, :string
    field :content, :string
    field :version, :integer, default: 0
    field :shared_users, {:array, :string}
    belongs_to :user, LiveSveltePheonix.Accounts.User
    timestamps(type: :naive_datetime)
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:session_id, :content, :version, :shared_users, :user_id])
    |> validate_required([:session_id, :user_id])
    |> unique_constraint(:session_id)
  end

  def update_content(session_id, content, version) do
    session = LiveSveltePheonix.Repo.get_by(__MODULE__, session_id: session_id)

    session
    |> changeset(%{content: content, version: version})
    |> LiveSveltePheonix.Repo.update!()
  end

  def update_shared_users(session_id, user_email) do
    session = LiveSveltePheonix.Repo.get_by(__MODULE__, session_id: session_id)
    shared_users = session.shared_users || []

    if user_email in shared_users do
      {:error, "User already invited"}
    else
      session
      |> changeset(%{shared_users: shared_users ++ [user_email]})
      |> LiveSveltePheonix.Repo.update!()

      {:ok, "User invited successfully"}
    end
  end
end

require Protocol

Protocol.derive(Jason.Encoder, LiveSveltePheonix.Session,
  only: [:id, :session_id, :content, :version, :shared_users, :user_id, :inserted_at, :updated_at]
)
