defmodule LiveSveltePheonix.Repo.Migrations.AddModeToSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add :mode, :string, null: false, default: "text"
    end
  end
end
