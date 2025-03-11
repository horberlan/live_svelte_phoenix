defmodule LiveSveltePheonix.Repo.Migrations.CreateSessions do
  use Ecto.Migration

  def change do
    create table(:sessions) do
      add :session_id, :string, null: false
      add :content, :string
      add :shared_users, {:array, :string}
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:sessions, [:session_id])
    create index(:sessions, [:user_id])
  end
end
