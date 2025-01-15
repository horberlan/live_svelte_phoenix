defmodule LiveSveltePheonix.Repo.Migrations.CreateSessions do
  use Ecto.Migration

  def change do
    create table(:sessions) do
      add :user_id, references(:users, on_delete: :nothing)
      add :session_id, :string
      add :content, :text
      add :shared_users, {:array, :string}

      timestamps()
    end

    create index(:sessions, [:user_id])
  end
end
