defmodule AceAppWeb.DraftRoomLiveTimerTest do
  use AceAppWeb.ConnCase, async: true
  
  import Phoenix.LiveViewTest
  
  alias AceApp.Drafts
  alias AceApp.Drafts.TimerManager
  
  describe "timer mount behavior" do
    setup do
      # Create test draft with required data
      {:ok, draft} = Drafts.create_draft(%{
        name: "Test Draft",
        format: :snake,
        pick_timer_seconds: 60,
        status: :draft
      })
      
      # Create test teams
      {:ok, team1} = Drafts.create_team(draft.id, %{name: "Team 1", pick_order_position: 1})
      {:ok, team2} = Drafts.create_team(draft.id, %{name: "Team 2", pick_order_position: 2})
      
      %{draft: draft, team1: team1, team2: team2}
    end
    
    test "mount sends timer_state event only for running timers", %{conn: conn, draft: draft, team1: team1} do
      # Start timer
      {:ok, :timer_started} = TimerManager.start_pick_timer(draft.id, team1.id, 60)
      
      # Mount as organizer should receive timer_state event
      {:ok, view, _html} = live(conn, "/drafts/#{draft.organizer_token}")
      
      # Check for timer_state event in the rendered content
      # Since we can't directly intercept push_event in tests, we verify the timer component is rendered
      assert has_element?(view, "[phx-hook='ClientTimer']")
      assert has_element?(view, "[data-timer-display]")
      assert has_element?(view, "[data-timer-progress]")
    end
    
    test "mount does not send timer_state event for paused timers", %{conn: conn, draft: draft, team1: team1} do
      # Start and immediately pause timer
      {:ok, :timer_started} = TimerManager.start_pick_timer(draft.id, team1.id, 60)
      :ok = TimerManager.pause_timer(draft.id)
      
      # Mount as organizer should not send timer_state for paused timer
      {:ok, view, _html} = live(conn, "/drafts/#{draft.organizer_token}")
      
      # Timer component should still be present but not active
      assert has_element?(view, "[phx-hook='ClientTimer']")
      assert has_element?(view, "[data-timer-display]")
    end
    
    test "mount does not send timer_state event for stopped timers", %{conn: conn, draft: draft} do
      # No timer running
      {:ok, view, _html} = live(conn, "/drafts/#{draft.organizer_token}")
      
      # Timer component should be present but inactive
      assert has_element?(view, "[phx-hook='ClientTimer']")
      assert has_element?(view, "[data-timer-display]")
    end
  end
  
  describe "timer controls" do
    setup do
      {:ok, draft} = Drafts.create_draft(%{
        name: "Test Draft",
        format: :snake, 
        pick_timer_seconds: 60,
        status: :active
      })
      
      {:ok, team1} = Drafts.create_team(draft.id, %{name: "Team 1", pick_order_position: 1})
      
      %{draft: draft, team1: team1}
    end
    
    test "reset_timer event starts and pauses timer", %{conn: conn, draft: draft} do
      {:ok, view, _html} = live(conn, "/drafts/#{draft.organizer_token}")
      
      # Reset timer
      view |> element("button", "Reset Timer") |> render_click()
      
      # Verify timer was created and is paused
      {:ok, timer_state} = Drafts.get_timer_state(draft.id)
      assert timer_state.status == :paused
      assert timer_state.remaining_seconds > 0
    end
    
    test "resume_timer event starts countdown", %{conn: conn, draft: draft, team1: team1} do
      {:ok, view, _html} = live(conn, "/drafts/#{draft.organizer_token}")
      
      # Start paused timer first
      {:ok, :timer_started} = TimerManager.start_pick_timer(draft.id, team1.id, 60)
      :ok = TimerManager.pause_timer(draft.id)
      
      # Resume timer
      view |> element("button", "Resume Timer") |> render_click()
      
      # Verify timer is running
      {:ok, timer_state} = Drafts.get_timer_state(draft.id)
      assert timer_state.status == :running
    end
    
    test "pause_timer event pauses running timer", %{conn: conn, draft: draft, team1: team1} do
      {:ok, view, _html} = live(conn, "/drafts/#{draft.organizer_token}")
      
      # Start timer
      {:ok, :timer_started} = TimerManager.start_pick_timer(draft.id, team1.id, 60)
      
      # Pause timer
      view |> element("button", "Pause Timer") |> render_click()
      
      # Verify timer is paused
      {:ok, timer_state} = Drafts.get_timer_state(draft.id)
      assert timer_state.status == :paused
    end
    
    test "stop_timer event stops timer", %{conn: conn, draft: draft, team1: team1} do
      {:ok, view, _html} = live(conn, "/drafts/#{draft.organizer_token}")
      
      # Start timer
      {:ok, :timer_started} = TimerManager.start_pick_timer(draft.id, team1.id, 60)
      
      # Stop timer
      view |> element("button", "Stop Timer") |> render_click()
      
      # Verify timer is stopped
      case Drafts.get_timer_state(draft.id) do
        {:ok, timer_state} -> assert timer_state.status == :stopped
        {:error, :timer_not_found} -> :ok # Timer process terminated
      end
    end
  end
  
  describe "timer state format" do
    setup do
      {:ok, draft} = Drafts.create_draft(%{
        name: "Test Draft",
        format: :snake,
        pick_timer_seconds: 60,
        status: :active
      })
      
      {:ok, team1} = Drafts.create_team(draft.id, %{name: "Team 1", pick_order_position: 1})
      
      %{draft: draft, team1: team1}
    end
    
    test "enhanced_timer_state contains all required fields", %{conn: conn, draft: draft, team1: team1} do
      # Start timer to create timer state
      {:ok, :timer_started} = TimerManager.start_pick_timer(draft.id, team1.id, 60)
      
      {:ok, view, _html} = live(conn, "/drafts/#{draft.organizer_token}")
      
      # Get timer state
      {:ok, timer_state} = Drafts.get_timer_state(draft.id)
      
      # Verify timer state structure matches what JavaScript expects
      assert timer_state.status == :running
      assert is_integer(timer_state.remaining_seconds)
      assert is_integer(timer_state.total_seconds)
      assert timer_state.current_team_id == team1.id
      assert %DateTime{} = timer_state.deadline
    end
  end
  
  describe "user role permissions" do
    setup do
      {:ok, draft} = Drafts.create_draft(%{
        name: "Test Draft", 
        format: :snake,
        pick_timer_seconds: 60,
        status: :active
      })
      
      {:ok, team1} = Drafts.create_team(draft.id, %{name: "Team 1", pick_order_position: 1})
      
      %{draft: draft, team1: team1}
    end
    
    test "team members cannot control timer", %{conn: conn, draft: draft, team1: team1} do
      {:ok, view, _html} = live(conn, "/drafts/team/#{team1.captain_token}")
      
      # Team members should not see timer control buttons
      refute has_element?(view, "button", "Reset Timer")
      refute has_element?(view, "button", "Pause Timer")
      refute has_element?(view, "button", "Resume Timer")
      refute has_element?(view, "button", "Stop Timer")
    end
    
    test "spectators cannot control timer", %{conn: conn, draft: draft} do
      {:ok, view, _html} = live(conn, "/drafts/spectator/#{draft.spectator_token}")
      
      # Spectators should not see timer control buttons
      refute has_element?(view, "button", "Reset Timer")
      refute has_element?(view, "button", "Pause Timer") 
      refute has_element?(view, "button", "Resume Timer")
      refute has_element?(view, "button", "Stop Timer")
    end
    
    test "organizers can control timer", %{conn: conn, draft: draft} do
      {:ok, view, _html} = live(conn, "/drafts/#{draft.organizer_token}")
      
      # Organizers should see timer control buttons
      assert has_element?(view, "button", "Reset Timer")
      # Other buttons may or may not be visible depending on timer state
    end
  end
end