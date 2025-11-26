defmodule LiveSveltePheonix.Drawing.Stroke do
  use Ecto.Schema
  import Ecto.Changeset

  schema "drawing_strokes" do
    field :session_id, :string
    field :path_data, :string
    field :color, :string
    field :stroke_width, :float, default: 2.0
    field :user_id, :string

    timestamps(type: :naive_datetime)
  end

  @doc """
  Creates a changeset for a stroke with validations.

  Validations:
  - session_id, path_data, and color are required
  - color must be a valid hex color format (#RRGGBB)
  - path_data must be between 1 and 100,000 characters
  - stroke_width must be greater than 0 and less than or equal to 50
  """
  def changeset(stroke, attrs) do
    stroke
    |> cast(attrs, [:session_id, :path_data, :color, :stroke_width, :user_id])
    |> validate_required([:session_id, :path_data, :color])
    |> validate_format(:color, ~r/^#[0-9A-Fa-f]{6}$/, message: "must be a valid hex color")
    |> validate_length(:path_data, min: 1, max: 100_000)
    |> validate_number(:stroke_width, greater_than: 0, less_than_or_equal_to: 50)
  end
end
