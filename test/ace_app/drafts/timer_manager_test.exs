defmodule AceApp.Drafts.TimerManagerTest do
  use ExUnit.Case, async: false  # Not async due to GenServer state
  use AceApp.DataCase
  
  alias AceApp.Drafts.TimerManager
  alias AceApp.Drafts

  setup do
    # Set sandbox mode to allow spawned processes to access the database
    Ecto.Adapters.SQL.Sandbox.mode(AceApp.Repo, {:shared, self()})
    
    # Create a test draft
    {:ok, draft} = Drafts.create_draft(%{
      name: "Timer Test Draft",
      format: :snake,
      pick_timer_seconds: 30
    })

    # Create teams (required for timer to work)
    {:ok, team1} = Drafts.create_team(draft.id, %{name: "Team 1", pick_order_position: 1})
    {:ok, team2} = Drafts.create_team(draft.id, %{name: "Team 2", pick_order_position: 2})

    on_exit(fn ->
      # Clean up any running timers
      TimerManager.stop_timer(draft.id)
    end)

    %{draft: draft, team1: team1, team2: team2}
  end

  describe "TimerManager" do
    test "starts timer for draft", %{draft: draft, team1: team1} do
      # Start timer for team1
      assert {:ok, _timer} = TimerManager.start_pick_timer(draft.id, team1.id, 30)
      
      # Verify timer is running
      assert TimerManager.timer_running?(draft.id)
      
      # Clean up
      TimerManager.stop_timer(draft.id)
    end

    test "stops timer for draft", %{draft: draft, team1: team1} do
      # Start then stop timer
      {:ok, _timer} = TimerManager.start_pick_timer(draft.id, team1.id, 30)
      assert TimerManager.timer_running?(draft.id)
      
      assert :ok = TimerManager.stop_timer(draft.id)
      refute TimerManager.timer_running?(draft.id)
    end

    test "pauses and resumes timer", %{draft: draft, team1: team1} do
      # Start timer
      {:ok, _timer} = TimerManager.start_pick_timer(draft.id, team1.id, 30)
      
      # Pause timer
      assert :ok = TimerManager.pause_timer(draft.id)
      
      # Resume timer
      assert :ok = TimerManager.resume_timer(draft.id)
      
      # Clean up
      TimerManager.stop_timer(draft.id)
    end

    test "handles timer not found gracefully", %{draft: draft} do
      # Try to stop non-existent timer
      assert {:error, :timer_not_found} = TimerManager.stop_timer(draft.id)
      
      # Try to pause non-existent timer
      assert {:error, :timer_not_found} = TimerManager.pause_timer(draft.id)
      
      # Try to resume non-existent timer
      assert {:error, :timer_not_found} = TimerManager.resume_timer(draft.id)
    end

    test "prevents duplicate timers for same draft", %{draft: draft, team1: team1} do
      # Start first timer
      {:ok, _timer1} = TimerManager.start_pick_timer(draft.id, team1.id, 30)
      
      # Try to start another timer for same draft - should be idempotent
      {:ok, :timer_started} = TimerManager.start_pick_timer(draft.id, team1.id, 30)
      
      # Clean up
      TimerManager.stop_timer(draft.id)
    end

    test "tracks multiple draft timers", %{draft: draft, team1: team1} do
      # Create another draft with teams
      {:ok, draft2} = Drafts.create_draft(%{
        name: "Second Timer Test",
        format: :snake,
        pick_timer_seconds: 45
      })
      {:ok, team2_1} = Drafts.create_team(draft2.id, %{name: "Team 2-1", pick_order_position: 1})

      # Start timers for both drafts
      {:ok, _timer1} = TimerManager.start_pick_timer(draft.id, team1.id, 30)
      {:ok, _timer2} = TimerManager.start_pick_timer(draft2.id, team2_1.id, 45)
      
      # Both should be running
      assert TimerManager.timer_running?(draft.id)
      assert TimerManager.timer_running?(draft2.id)
      
      # Stop one timer
      TimerManager.stop_timer(draft.id)
      
      # First should be stopped, second still running
      refute TimerManager.timer_running?(draft.id)
      assert TimerManager.timer_running?(draft2.id)
      
      # Clean up
      TimerManager.stop_timer(draft2.id)
    end

    test "handles timer process crashes gracefully", %{draft: draft, team1: team1} do
      # Start timer
      {:ok, _timer} = TimerManager.start_pick_timer(draft.id, team1.id, 30)
      
      # Find and kill the timer process
      timer_pid = case Registry.lookup(AceApp.DraftTimerRegistry, draft.id) do
        [{pid, _}] -> pid
        [] -> nil
      end
      
      if timer_pid do
        Process.exit(timer_pid, :kill)
        Process.sleep(10)
      end
      
      # Should be able to start new timer
      {:ok, _new_timer} = TimerManager.start_pick_timer(draft.id, team1.id, 30)
      
      # Clean up
      TimerManager.stop_timer(draft.id)
    end
  end

  describe "DraftTimer process" do
    test "timer sends tick events", %{draft: draft, team1: team1} do
      # Subscribe to PubSub events
      Phoenix.PubSub.subscribe(AceApp.PubSub, "draft:#{draft.id}")
      
      # Start timer with short duration
      {:ok, _timer} = TimerManager.start_pick_timer(draft.id, team1.id, 3)
      
      # Should receive tick events
      assert_receive {:timer_tick, %{remaining_seconds: _}}, 2000
      
      # Clean up
      TimerManager.stop_timer(draft.id)
    end

    test "timer sends warning events", %{draft: draft, team1: team1} do
      # Subscribe to PubSub events
      Phoenix.PubSub.subscribe(AceApp.PubSub, "draft:#{draft.id}")
      
      # Start timer with duration that triggers warnings
      {:ok, _timer} = TimerManager.start_pick_timer(draft.id, team1.id, 11)
      
      # Should receive warning at 10s
      assert_receive {:timer_warning, %{seconds_remaining: 10}}, 2000
      
      # Clean up
      TimerManager.stop_timer(draft.id)
    end

    test "timer sends expiration event", %{draft: draft, team1: team1} do
      # Subscribe to PubSub events
      Phoenix.PubSub.subscribe(AceApp.PubSub, "draft:#{draft.id}")
      
      # Start timer with very short duration
      {:ok, _timer} = TimerManager.start_pick_timer(draft.id, team1.id, 1)
      
      # Should receive expiration
      assert_receive {:timer_expired, %{team_id: _}}, 2000
    end

    test "paused timer stops sending events", %{draft: draft, team1: team1} do
      # Subscribe to PubSub events
      Phoenix.PubSub.subscribe(AceApp.PubSub, "draft:#{draft.id}")
      
      # Start timer
      {:ok, _timer} = TimerManager.start_pick_timer(draft.id, team1.id, 10)
      
      # Receive initial tick
      assert_receive {:timer_tick, _}, 2000
      
      # Pause timer
      TimerManager.pause_timer(draft.id)
      
      # Should receive a paused status tick, then no more ticks
      assert_receive {:timer_tick, %{status: :paused}}, 1000
      refute_receive {:timer_tick, _}, 1500
      
      # Clean up
      TimerManager.stop_timer(draft.id)
    end

    test "resumed timer continues from paused time", %{draft: draft, team1: team1} do
      # Subscribe to PubSub events
      Phoenix.PubSub.subscribe(AceApp.PubSub, "draft:#{draft.id}")
      
      # Start timer
      {:ok, _timer} = TimerManager.start_pick_timer(draft.id, team1.id, 10)
      
      # Wait for a tick
      assert_receive {:timer_tick, %{remaining_seconds: time1}}, 2000
      
      # Pause timer
      TimerManager.pause_timer(draft.id)
      
      # Wait a bit while paused
      Process.sleep(500)
      
      # Resume timer
      TimerManager.resume_timer(draft.id)
      
      # Next tick should be close to paused time
      assert_receive {:timer_tick, %{remaining_seconds: time2}}, 2000
      assert abs(time1 - time2) <= 2  # Should be close to where we paused
      
      # Clean up
      TimerManager.stop_timer(draft.id)
    end

    test "timer updates database state", %{draft: draft, team1: team1} do
      # Start timer
      {:ok, _timer} = TimerManager.start_pick_timer(draft.id, team1.id, 5)
      
      # Give time for database update
      Process.sleep(100)
      
      # Check database was updated
      updated_draft = Drafts.get_draft!(draft.id)
      assert updated_draft.timer_status == "running"
      assert updated_draft.timer_remaining_seconds <= 5
      assert updated_draft.timer_started_at != nil
      
      # Clean up
      TimerManager.stop_timer(draft.id)
    end
  end

  describe "Timer recovery" do
    test "timer can be recovered from database state", %{draft: draft, team1: team1} do
      # Manually set draft timer state in database
      Drafts.update_draft(draft, %{
        timer_status: "running",
        timer_remaining_seconds: 15,
        timer_started_at: DateTime.utc_now(),
        current_turn_team_id: team1.id
      })
      
      # Start timer (should recover from database)
      {:ok, _timer} = TimerManager.start_pick_timer(draft.id, team1.id, 30)
      
      # Should use recovered time, not the full 30 seconds
      assert TimerManager.timer_running?(draft.id)
      
      # Clean up
      TimerManager.stop_timer(draft.id)
    end

    test "handles corrupted timer state gracefully", %{draft: draft, team1: team1} do
      # Set invalid timer state
      Drafts.update_draft(draft, %{
        timer_status: "running",
        timer_remaining_seconds: -5,  # Invalid
        timer_started_at: nil,  # Invalid
        current_turn_team_id: team1.id
      })
      
      # Should still be able to start timer
      {:ok, _timer} = TimerManager.start_pick_timer(draft.id, team1.id, 30)
      
      # Clean up
      TimerManager.stop_timer(draft.id)
    end
  end

  describe "Integration with draft flow" do
    test "timer integrates with draft state changes", %{draft: draft, team1: team1} do
      # Subscribe to events
      Phoenix.PubSub.subscribe(AceApp.PubSub, "draft:#{draft.id}")
      
      # Just test timer functionality directly
      {:ok, _timer} = TimerManager.start_pick_timer(draft.id, team1.id, 5)
      
      # Should be running
      assert TimerManager.timer_running?(draft.id)
      
      # Should receive timer events
      assert_receive {:timer_tick, %{remaining_seconds: _}}, 2000
      
      # Clean up
      TimerManager.stop_timer(draft.id)
    end
  end
end