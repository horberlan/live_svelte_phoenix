defmodule LiveSveltePheonix.Repo.Migrations.AlterSessionsContentToText do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      modify :content, :text
    end
  end
end
