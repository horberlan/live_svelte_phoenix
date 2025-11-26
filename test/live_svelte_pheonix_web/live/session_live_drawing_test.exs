defmodule LiveSveltePheonixWeb.SessionLiveDrawingTest do
  @moduledoc """
  Property-based tests for collaborative drawing functionality in SessionLive.
  **Feature: collaborative-drawing, Property 4: Stroke broadcast on completion**
  **Validates: Requirements 1.4, 4.2**
  """
  use LiveSveltePheonixWeb.ConnCase, async: false

  alias LiveSveltePheonix.Drawing
  alias LiveSveltePheonix.Repo
  alias LiveSveltePheonix.Session
  import Phoenix.LiveViewTest
  import LiveSveltePheonix.AccountsFixtures

  @pubsub LiveSveltePheonix.PubSub

  describe "handle_info for new_stroke" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "updates drawing_strokes assigns and pushes event to client", %{conn: conn, user: user} do
      session_id = "test-session-handle-info"
      create_test_session(session_id, user)

      # Mount the LiveView
      {:ok, view, _html} = live(conn, "/session/#{session_id}")

      # Get initial state
      initial_strokes = :sys.get_state(view.pid).socket.assigns.drawing_strokes
      assert initial_strokes == []

      # Simulate receiving a broadcast by sending handle_info message directly
      stroke_data = %{
        path: "M10,10 L50,50",
        color: "#FF0000",
        strokeWidth: 3.0
      }

      send(view.pid, {:new_stroke, stroke_data})

      # Give it a moment to process
      :timer.sleep(100)

      # Verify assigns were updated
      updated_strokes = :sys.get_state(view.pid).socket.assigns.drawing_strokes
      assert length(updated_strokes) == 1

      # Verify the stroke has correct format (camelCase converted to snake_case)
      [stroke] = updated_strokes
      assert stroke.path_data == "M10,10 L50,50"
      assert stroke.color == "#FF0000"
      assert stroke.stroke_width == 3.0

      # Send another stroke
      stroke_data_2 = %{
        path: "M100,100 L200,200",
        color: "#00FF00",
        strokeWidth: 5.0
      }

      send(view.pid, {:new_stroke, stroke_data_2})
      :timer.sleep(100)

      # Verify both strokes are in assigns
      final_strokes = :sys.get_state(view.pid).socket.assigns.drawing_strokes
      assert length(final_strokes) == 2

      # Cleanup
      cleanup_test_session(session_id)
    end
  end

  describe "Property 4: Stroke broadcast on completion" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    @tag :property
    test "for any completed stroke, a PubSub message should be broadcast", %{conn: conn, user: user} do
      # Run property test with 100 iterations using different combinations
      test_cases = generate_test_cases(100)

      results = Enum.map(test_cases, fn {session_id, path, color} ->
        test_stroke_broadcast(conn, user, session_id, path, color)
      end)

      # All tests should pass
      assert Enum.all?(results, & &1), "Some stroke broadcasts failed"
    end
  end

  # Test a single stroke broadcast
  defp test_stroke_broadcast(conn, user, session_id, path, color) do
    try do
      # Setup: Create session
      create_test_session(session_id, user)

      # Subscribe to the drawing topic to capture broadcasts
      topic = "drawing:#{session_id}"
      Phoenix.PubSub.subscribe(@pubsub, topic)

      # Mount the LiveView
      {:ok, view, _html} = live(conn, "/session/#{session_id}")

      # Trigger the stroke_drawn event
      render_hook(view, "stroke_drawn", %{
        "path" => path,
        "color" => color
      })

      # Assert: Check that a PubSub broadcast was received
      broadcast_received =
        receive do
          {:new_stroke, stroke_data} ->
            # Verify the broadcast contains the correct data
            stroke_data.path == path and
            stroke_data.color == color and
            is_float(stroke_data.strokeWidth)
        after
          1000 -> false
        end

      # Cleanup
      Phoenix.PubSub.unsubscribe(@pubsub, topic)
      cleanup_test_session(session_id)

      broadcast_received
    rescue
      e ->
        IO.puts("Error in test: #{inspect(e)}")
        false
    end
  end

  # Generate test cases (simulating property-based testing)
  defp generate_test_cases(count) do
    session_ids = ["test-session-1", "test-session-2", "test-session-3", "test-session-4", "test-session-5"]
    paths = [
      "M10,10 L20,20",
      "M50,50 L100,100 L150,50",
      "M0,0 L100,0 L100,100 L0,100",
      "M200,200 L250,250 L300,200 L250,150",
      "M10,50 L50,10 L90,50 L50,90 L10,50"
    ]
    colors = [
      "#000000",
      "#FF0000",
      "#00FF00",
      "#0000FF",
      "#FFFF00",
      "#FF00FF",
      "#00FFFF",
      "#FFFFFF"
    ]

    # Generate random combinations
    for _ <- 1..count do
      {
        Enum.random(session_ids),
        Enum.random(paths),
        Enum.random(colors)
      }
    end
  end

  describe "clear canvas broadcast flow" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "clear_and_broadcast/2 broadcasts to all users", %{conn: conn, user: user} do
      session_id = "test-session-clear-broadcast"
      create_test_session(session_id, user)

      # Create some strokes first
      {:ok, _stroke1} = Drawing.create_stroke(%{
        session_id: session_id,
        path_data: "M10,10 L20,20",
        color: "#000000",
        stroke_width: 2.0,
        user_id: "user-#{user.id}"
      })

      {:ok, _stroke2} = Drawing.create_stroke(%{
        session_id: session_id,
        path_data: "M30,30 L40,40",
        color: "#FF0000",
        stroke_width: 3.0,
        user_id: "user-#{user.id}"
      })

      # Verify strokes exist
      {:ok, strokes_before} = Drawing.list_strokes_by_session(session_id)
      assert length(strokes_before) == 2

      # Subscribe to the drawing topic to capture broadcasts
      topic = "drawing:#{session_id}"
      Phoenix.PubSub.subscribe(@pubsub, topic)

      # Mount the LiveView
      {:ok, view, _html} = live(conn, "/session/#{session_id}")

      # Trigger the clear_canvas event
      render_hook(view, "clear_canvas", %{})

      # Assert: Check that a PubSub broadcast was received
      assert_receive {:clear_canvas, ^session_id}, 1000

      # Verify strokes were deleted from database
      {:ok, strokes_after} = Drawing.list_strokes_by_session(session_id)
      assert strokes_after == []

      # Cleanup
      Phoenix.PubSub.unsubscribe(@pubsub, topic)
      cleanup_test_session(session_id)
    end

    test "handle_info({:clear_canvas, session_id}, socket) updates assigns to empty list", %{conn: conn, user: user} do
      session_id = "test-session-clear-handle-info"
      create_test_session(session_id, user)

      # Create some strokes first
      {:ok, _stroke1} = Drawing.create_stroke(%{
        session_id: session_id,
        path_data: "M10,10 L20,20",
        color: "#000000",
        stroke_width: 2.0,
        user_id: "user-#{user.id}"
      })

      {:ok, _stroke2} = Drawing.create_stroke(%{
        session_id: session_id,
        path_data: "M30,30 L40,40",
        color: "#FF0000",
        stroke_width: 3.0,
        user_id: "user-#{user.id}"
      })

      # Mount the LiveView (it will load the 2 strokes from DB)
      {:ok, view, _html} = live(conn, "/session/#{session_id}")

      :timer.sleep(100)

      # Verify strokes are in assigns (loaded from DB on mount)
      strokes_before = :sys.get_state(view.pid).socket.assigns.drawing_strokes
      assert length(strokes_before) == 2

      # Send clear_canvas message
      send(view.pid, {:clear_canvas, session_id})
      :timer.sleep(100)

      # Verify assigns were updated to empty list
      strokes_after = :sys.get_state(view.pid).socket.assigns.drawing_strokes
      assert strokes_after == []

      # Cleanup
      cleanup_test_session(session_id)
    end

    test "DrawingCanvas clears canvas on clear_canvas event", %{conn: conn, user: user} do
      session_id = "test-session-clear-canvas-event"
      create_test_session(session_id, user)

      # Create some strokes first
      {:ok, _stroke1} = Drawing.create_stroke(%{
        session_id: session_id,
        path_data: "M10,10 L20,20",
        color: "#000000",
        stroke_width: 2.0,
        user_id: "user-#{user.id}"
      })

      # Mount the LiveView
      {:ok, view, _html} = live(conn, "/session/#{session_id}")

      # Enable drawing mode
      render_hook(view, "toggle_drawing_mode", %{})
      :timer.sleep(100)

      # Verify we're in drawing mode
      assert :sys.get_state(view.pid).socket.assigns.drawing_mode == true

      # Clear the canvas
      render_hook(view, "clear_canvas", %{})
      :timer.sleep(100)

      # Verify assigns were cleared
      strokes_after = :sys.get_state(view.pid).socket.assigns.drawing_strokes
      assert strokes_after == []

      # Verify database was cleared
      {:ok, db_strokes} = Drawing.list_strokes_by_session(session_id)
      assert db_strokes == []

      # Cleanup
      cleanup_test_session(session_id)
    end

    test "multi-user clear synchronization", %{conn: conn, user: user} do
      session_id = "test-session-multi-user-clear"
      create_test_session(session_id, user)

      # Create some strokes
      {:ok, _stroke1} = Drawing.create_stroke(%{
        session_id: session_id,
        path_data: "M10,10 L20,20",
        color: "#000000",
        stroke_width: 2.0,
        user_id: "user-#{user.id}"
      })

      # Mount two LiveView processes for the same session (simulating two users)
      {:ok, view1, _html1} = live(conn, "/session/#{session_id}")
      {:ok, view2, _html2} = live(conn, "/session/#{session_id}")

      # Subscribe view2 to drawing topic to receive broadcasts
      topic = "drawing:#{session_id}"
      Phoenix.PubSub.subscribe(@pubsub, topic)

      # User 1 clears the canvas
      render_hook(view1, "clear_canvas", %{})
      :timer.sleep(100)

      # Assert: User 2 receives the broadcast
      assert_receive {:clear_canvas, ^session_id}, 1000

      # Verify both views have empty strokes
      strokes_view1 = :sys.get_state(view1.pid).socket.assigns.drawing_strokes
      strokes_view2 = :sys.get_state(view2.pid).socket.assigns.drawing_strokes
      assert strokes_view1 == []
      assert strokes_view2 == []

      # Verify database is empty
      {:ok, db_strokes} = Drawing.list_strokes_by_session(session_id)
      assert db_strokes == []

      # Cleanup
      Phoenix.PubSub.unsubscribe(@pubsub, topic)
      cleanup_test_session(session_id)
    end
  end

  # --- Helper Functions ---

  defp create_test_session(session_id, user) do
    %Session{}
    |> Session.changeset(%{session_id: session_id, user_id: user.id})
    |> Repo.insert!(on_conflict: :nothing)
  end

  defp cleanup_test_session(session_id) do
    # Clean up strokes
    Drawing.delete_strokes_by_session(session_id)

    # Clean up session
    case Repo.get_by(Session, session_id: session_id) do
      nil -> :ok
      session -> Repo.delete(session)
    end
  end
end
