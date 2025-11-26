defmodule LiveSveltePheonix.Repo.Migrations.CreateDrawingStrokes do
  use Ecto.Migration

  def change do
    create table(:drawing_strokes) do
      add :session_id, :string, null: false
      add :path_data, :text, null: false
      add :color, :string, null: false
      add :stroke_width, :float, default: 2.0
      add :user_id, :string

      timestamps(type: :naive_datetime)
    end

    create index(:drawing_strokes, [:session_id])
    create index(:drawing_strokes, [:inserted_at])
  end
end
