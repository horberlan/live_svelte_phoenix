defmodule LiveSveltePheonix.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users_2" do
    field :username, :string
    field :active_session, :string

    has_many :sessions, LiveSveltePheonix.Session

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :active_session])
    |> validate_required([:username])
    |> unique_constraint(:username)
  end
end
