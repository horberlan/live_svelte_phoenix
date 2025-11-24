defmodule LiveSveltePheonix.Repo.Migrations.AddYdocToSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add :ydoc, :binary
    end
  end
end
