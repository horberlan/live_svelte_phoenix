defmodule LiveSveltePheonix.Drawing.RateLimiterTest do
  use ExUnit.Case, async: false

  alias LiveSveltePheonix.Drawing.RateLimiter

  setup do
    # Ensure the rate limiter is started
    # It should already be started by the application, but we'll verify
    case Process.whereis(RateLimiter) do
      nil -> {:error, "RateLimiter not started"}
      _pid -> :ok
    end

    # Use a unique session ID for each test
    session_id = "test-session-#{:rand.uniform(1_000_000)}"
    {:ok, session_id: session_id}
  end

  describe "stroke rate limiting" do
    test "allows strokes within limit", %{session_id: session_id} do
      # Should allow first stroke
      assert {:ok, _remaining} = RateLimiter.check_stroke_limit(session_id)
      RateLimiter.record_stroke(session_id)

      # Should allow second stroke
      assert {:ok, _remaining} = RateLimiter.check_stroke_limit(session_id)
      RateLimiter.record_stroke(session_id)
    end

    test "blocks strokes when limit exceeded", %{session_id: session_id} do
      # Record 100 strokes (the limit)
      for _ <- 1..100 do
        assert {:ok, _} = RateLimiter.check_stroke_limit(session_id)
        RateLimiter.record_stroke(session_id)
      end

      # 101st stroke should be blocked
      assert {:error, :rate_limit_exceeded} = RateLimiter.check_stroke_limit(session_id)
    end

    test "returns correct remaining count", %{session_id: session_id} do
      # First check should show 99 remaining (100 limit - 1)
      assert {:ok, 99} = RateLimiter.check_stroke_limit(session_id)
      RateLimiter.record_stroke(session_id)

      # Second check should show 98 remaining
      assert {:ok, 98} = RateLimiter.check_stroke_limit(session_id)
    end

    test "counts strokes correctly", %{session_id: session_id} do
      # Initially should be 0
      assert RateLimiter.get_count(session_id, :stroke) == 0

      # Record 5 strokes
      for _ <- 1..5 do
        RateLimiter.record_stroke(session_id)
      end

      # Should count 5
      assert RateLimiter.get_count(session_id, :stroke) == 5
    end
  end

  describe "clear rate limiting" do
    test "allows clears within limit", %{session_id: session_id} do
      # Should allow first clear
      assert {:ok, _remaining} = RateLimiter.check_clear_limit(session_id)
      RateLimiter.record_clear(session_id)

      # Should allow second clear
      assert {:ok, _remaining} = RateLimiter.check_clear_limit(session_id)
      RateLimiter.record_clear(session_id)
    end

    test "blocks clears when limit exceeded", %{session_id: session_id} do
      # Record 10 clears (the limit)
      for _ <- 1..10 do
        assert {:ok, _} = RateLimiter.check_clear_limit(session_id)
        RateLimiter.record_clear(session_id)
      end

      # 11th clear should be blocked
      assert {:error, :rate_limit_exceeded} = RateLimiter.check_clear_limit(session_id)
    end

    test "counts clears correctly", %{session_id: session_id} do
      # Initially should be 0
      assert RateLimiter.get_count(session_id, :clear) == 0

      # Record 3 clears
      for _ <- 1..3 do
        RateLimiter.record_clear(session_id)
      end

      # Should count 3
      assert RateLimiter.get_count(session_id, :clear) == 3
    end
  end

  describe "independent limits" do
    test "stroke and clear limits are independent", %{session_id: session_id} do
      # Record 10 strokes
      for _ <- 1..10 do
        RateLimiter.record_stroke(session_id)
      end

      # Should still allow clears
      assert {:ok, _} = RateLimiter.check_clear_limit(session_id)

      # Record 5 clears
      for _ <- 1..5 do
        RateLimiter.record_clear(session_id)
      end

      # Should still allow strokes (up to limit)
      assert {:ok, _} = RateLimiter.check_stroke_limit(session_id)
    end
  end
end
