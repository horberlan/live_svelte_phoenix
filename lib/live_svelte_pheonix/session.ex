defmodule LiveSveltePheonix.Session do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sessions" do
    field :session_id, :string
    field :content, :string
    field :shared_users, {:array, :string}
    belongs_to :user, LiveSveltePheonix.User
    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:session_id, :content, :shared_users, :user_id])
    |> validate_required([:session_id, :user_id])
  end

  def update_content(session_id, content) do
    session = LiveSveltePheonix.Repo.get_by(__MODULE__, session_id: session_id)

    session
    |> changeset(%{content: content})
    |> LiveSveltePheonix.Repo.update!()
  end
end
