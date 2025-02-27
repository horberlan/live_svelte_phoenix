defmodule LiveSveltePheonix.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :citext, null: false
      add :hashed_password, :string, null: false
      add :active_session, :string, null: true
      add :confirmed_at, :naive_datetime
      timestamps()
    end

    create unique_index(:users, [:email])
  end
end
