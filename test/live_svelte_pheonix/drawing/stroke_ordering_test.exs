defmodule LiveSveltePheonix.Drawing.StrokeOrderingTest do
  @moduledoc """
  Tests to verify stroke ordering is preserved throughout the system.
  This test validates Requirements 2.4 and 2.5 from the fix-drawing-rendering spec.
  """
  use LiveSveltePheonix.DataCase, async: true

  alias LiveSveltePheonix.Drawing
  alias LiveSveltePheonix.Drawing.Stroke

  describe "stroke ordering preservation" do
    test "list_strokes_by_session returns strokes ordered by inserted_at ascending" do
      session_id = "order-test-#{:rand.uniform(100000)}"

      # Create strokes with deliberate delays to ensure different timestamps
      stroke1_attrs = %{
        session_id: session_id,
        path_data: "M10,10 L20,20",
        color: "#FF0000",
        stroke_width: 2.0
      }

      {:ok, stroke1} = Drawing.create_stroke(stroke1_attrs)
      Process.sleep(10)  # Ensure different timestamp

      stroke2_attrs = %{
        session_id: session_id,
        path_data: "M30,30 L40,40",
        color: "#00FF00",
        stroke_width: 3.0
      }

      {:ok, stroke2} = Drawing.create_stroke(stroke2_attrs)
      Process.sleep(10)  # Ensure different timestamp

      stroke3_attrs = %{
        session_id: session_id,
        path_data: "M50,50 L60,60",
        color: "#0000FF",
        stroke_width: 4.0
      }

      {:ok, stroke3} = Drawing.create_stroke(stroke3_attrs)

      # Retrieve strokes
      {:ok, strokes} = Drawing.list_strokes_by_session(session_id)

      # Verify we got all three strokes
      assert length(strokes) == 3

      # Verify they are in the correct order (by ID, which reflects insertion order)
      [first, second, third] = strokes
      assert first.id == stroke1.id
      assert second.id == stroke2.id
      assert third.id == stroke3.id

      # Verify timestamps are in ascending order
      assert NaiveDateTime.compare(first.inserted_at, second.inserted_at) in [:lt, :eq]
      assert NaiveDateTime.compare(second.inserted_at, third.inserted_at) in [:lt, :eq]

      # Verify the actual data is correct
      assert first.path_data == "M10,10 L20,20"
      assert first.color == "#FF0000"
      assert second.path_data == "M30,30 L40,40"
      assert second.color == "#00FF00"
      assert third.path_data == "M50,50 L60,60"
      assert third.color == "#0000FF"
    end

    test "strokes maintain order even with rapid creation" do
      session_id = "rapid-order-test-#{:rand.uniform(100000)}"

      # Create 10 strokes rapidly
      stroke_ids = for i <- 1..10 do
        {:ok, stroke} = Drawing.create_stroke(%{
          session_id: session_id,
          path_data: "M#{i * 10},#{i * 10} L#{i * 20},#{i * 20}",
          color: "#000000",
          stroke_width: 2.0
        })
        stroke.id
      end

      # Retrieve strokes
      {:ok, strokes} = Drawing.list_strokes_by_session(session_id)

      # Verify all strokes are present
      assert length(strokes) == 10

      # Verify they are in the same order as created
      retrieved_ids = Enum.map(strokes, & &1.id)
      assert retrieved_ids == stroke_ids

      # Verify timestamps are monotonically increasing (or equal)
      timestamps = Enum.map(strokes, & &1.inserted_at)
      sorted_timestamps = Enum.sort(timestamps, NaiveDateTime)
      assert timestamps == sorted_timestamps
    end

    test "pagination preserves stroke order" do
      session_id = "pagination-order-test-#{:rand.uniform(100000)}"

      # Create 25 strokes
      for i <- 1..25 do
        {:ok, _stroke} = Drawing.create_stroke(%{
          session_id: session_id,
          path_data: "M#{i},#{i} L#{i + 10},#{i + 10}",
          color: "#000000",
          stroke_width: 2.0
        })
      end

      # Get all strokes
      {:ok, all_strokes} = Drawing.list_strokes_by_session(session_id)

      # Get first page (10 strokes)
      {:ok, page1} = Drawing.list_strokes_by_session(session_id, limit: 10, offset: 0)

      # Get second page (10 strokes)
      {:ok, page2} = Drawing.list_strokes_by_session(session_id, limit: 10, offset: 10)

      # Get third page (5 strokes)
      {:ok, page3} = Drawing.list_strokes_by_session(session_id, limit: 10, offset: 20)

      # Verify page sizes
      assert length(page1) == 10
      assert length(page2) == 10
      assert length(page3) == 5

      # Verify that concatenating pages gives the same order as all strokes
      paginated_strokes = page1 ++ page2 ++ page3
      assert Enum.map(paginated_strokes, & &1.id) == Enum.map(all_strokes, & &1.id)

      # Verify each page maintains chronological order
      assert_chronological_order(page1)
      assert_chronological_order(page2)
      assert_chronological_order(page3)
    end
  end

  # Helper function to assert timestamps are in chronological order
  defp assert_chronological_order(strokes) do
    timestamps = Enum.map(strokes, & &1.inserted_at)
    sorted_timestamps = Enum.sort(timestamps, NaiveDateTime)
    assert timestamps == sorted_timestamps
  end
end
