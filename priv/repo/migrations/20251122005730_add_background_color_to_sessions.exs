defmodule LiveSveltePheonix.Repo.Migrations.AddBackgroundColorToSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add :background_color, :string
    end
  end
end
