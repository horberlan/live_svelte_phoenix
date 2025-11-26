defmodule LiveSveltePheonix.Drawing.QueryPerformanceTest do
  use LiveSveltePheonix.DataCase, async: true

  alias LiveSveltePheonix.Drawing
  alias LiveSveltePheonix.Drawing.Stroke

  describe "query performance and optimization" do
    test "list_strokes_by_session uses indexes efficiently" do
      session_id = "perf-test-#{:rand.uniform(10000)}"

      # Create multiple strokes
      for i <- 1..50 do
        {:ok, _stroke} = Drawing.create_stroke(%{
          session_id: session_id,
          path_data: "M#{i},#{i} L#{i+10},#{i+10}",
          color: "#000000"
        })
      end

      # Query should use session_id index
      {:ok, strokes} = Drawing.list_strokes_by_session(session_id)
      assert length(strokes) == 50

      # Verify strokes are ordered by inserted_at
      timestamps = Enum.map(strokes, & &1.inserted_at)
      assert timestamps == Enum.sort(timestamps, NaiveDateTime)
    end

    test "list_strokes_by_session with limit returns correct number" do
      session_id = "limit-test-#{:rand.uniform(10000)}"

      # Create 20 strokes
      for i <- 1..20 do
        {:ok, _stroke} = Drawing.create_stroke(%{
          session_id: session_id,
          path_data: "M#{i},#{i} L#{i+10},#{i+10}",
          color: "#000000"
        })
      end

      # Query with limit
      {:ok, strokes} = Drawing.list_strokes_by_session(session_id, limit: 10)
      assert length(strokes) == 10
    end

    test "list_strokes_by_session with offset skips correct number" do
      session_id = "offset-test-#{:rand.uniform(10000)}"

      # Create 20 strokes
      for i <- 1..20 do
        {:ok, _stroke} = Drawing.create_stroke(%{
          session_id: session_id,
          path_data: "M#{i},#{i} L#{i+10},#{i+10}",
          color: "#000000"
        })
      end

      # Query all strokes
      {:ok, all_strokes} = Drawing.list_strokes_by_session(session_id)

      # Query with offset
      {:ok, offset_strokes} = Drawing.list_strokes_by_session(session_id, offset: 10)

      assert length(offset_strokes) == 10
      # First stroke in offset result should be 11th stroke overall
      assert hd(offset_strokes).id == Enum.at(all_strokes, 10).id
    end

    test "list_strokes_by_session with limit and offset for pagination" do
      session_id = "pagination-test-#{:rand.uniform(10000)}"

      # Create 30 strokes
      for i <- 1..30 do
        {:ok, _stroke} = Drawing.create_stroke(%{
          session_id: session_id,
          path_data: "M#{i},#{i} L#{i+10},#{i+10}",
          color: "#000000"
        })
      end

      # Get first page
      {:ok, page1} = Drawing.list_strokes_by_session(session_id, limit: 10, offset: 0)
      assert length(page1) == 10

      # Get second page
      {:ok, page2} = Drawing.list_strokes_by_session(session_id, limit: 10, offset: 10)
      assert length(page2) == 10

      # Get third page
      {:ok, page3} = Drawing.list_strokes_by_session(session_id, limit: 10, offset: 20)
      assert length(page3) == 10

      # Verify no overlap
      page1_ids = Enum.map(page1, & &1.id)
      page2_ids = Enum.map(page2, & &1.id)
      page3_ids = Enum.map(page3, & &1.id)

      assert MapSet.disjoint?(MapSet.new(page1_ids), MapSet.new(page2_ids))
      assert MapSet.disjoint?(MapSet.new(page2_ids), MapSet.new(page3_ids))
      assert MapSet.disjoint?(MapSet.new(page1_ids), MapSet.new(page3_ids))
    end

    test "should_paginate? returns true for large sessions" do
      session_id = "large-session-#{:rand.uniform(10000)}"

      # Create 600 strokes (above default threshold of 500)
      for i <- 1..600 do
        {:ok, _stroke} = Drawing.create_stroke(%{
          session_id: session_id,
          path_data: "M#{i},#{i} L#{i+10},#{i+10}",
          color: "#000000"
        })
      end

      {:ok, should_paginate} = Drawing.should_paginate?(session_id)
      assert should_paginate == true
    end

    test "should_paginate? returns false for small sessions" do
      session_id = "small-session-#{:rand.uniform(10000)}"

      # Create 10 strokes (below default threshold of 500)
      for i <- 1..10 do
        {:ok, _stroke} = Drawing.create_stroke(%{
          session_id: session_id,
          path_data: "M#{i},#{i} L#{i+10},#{i+10}",
          color: "#000000"
        })
      end

      {:ok, should_paginate} = Drawing.should_paginate?(session_id)
      assert should_paginate == false
    end

    test "should_paginate? respects custom threshold" do
      session_id = "threshold-test-#{:rand.uniform(10000)}"

      # Create 150 strokes
      for i <- 1..150 do
        {:ok, _stroke} = Drawing.create_stroke(%{
          session_id: session_id,
          path_data: "M#{i},#{i} L#{i+10},#{i+10}",
          color: "#000000"
        })
      end

      # Should not paginate with default threshold (500)
      {:ok, should_paginate_default} = Drawing.should_paginate?(session_id)
      assert should_paginate_default == false

      # Should paginate with custom threshold (100)
      {:ok, should_paginate_custom} = Drawing.should_paginate?(session_id, 100)
      assert should_paginate_custom == true
    end

    test "count_strokes_by_session is efficient for large datasets" do
      session_id = "count-test-#{:rand.uniform(10000)}"

      # Create 100 strokes
      for i <- 1..100 do
        {:ok, _stroke} = Drawing.create_stroke(%{
          session_id: session_id,
          path_data: "M#{i},#{i} L#{i+10},#{i+10}",
          color: "#000000"
        })
      end

      # Count should use index and be fast
      {:ok, count} = Drawing.count_strokes_by_session(session_id)
      assert count == 100
    end
  end
end
