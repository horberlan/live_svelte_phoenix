# priv/repo/migrations/xxxxxxxx_add_position_to_sessions.exs
defmodule LiveSveltePheonix.Repo.Migrations.AddPositionToSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add :position, :integer, default: 0, null: false
    end

    create index(:sessions, [:user_id, :position])
  end
end
