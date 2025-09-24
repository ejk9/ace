defmodule AceAppWeb.DraftRoomLive do
  use AceAppWeb, :live_view
  require Logger

  alias AceApp.Drafts
  import AceAppWeb.Components.Timer

  @impl true
  def mount(%{"id" => draft_id}, _session, socket) do
    draft = Drafts.get_draft_with_associations!(draft_id)
    players = Drafts.list_available_players(draft_id) || []
    queued_picks = Drafts.list_queued_picks(draft_id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(AceApp.PubSub, "draft:#{draft_id}")
      Phoenix.PubSub.subscribe(AceApp.PubSub, "draft:#{draft_id}:chat")
    end

    current_phase = get_current_phase(draft)
    timer_state = get_timer_state(draft_id)
    
    socket = 
     socket
     |> assign(:draft, draft)
     |> assign(:players, players)
     |> assign(:filtered_players, players)
     |> assign(:search_term, "")
     |> assign(:selected_role, "all")
     |> assign(:current_phase, current_phase)
     |> assign(:current_pick_order, get_current_pick_order(draft))
     |> assign(:current_pick_number, length(draft.picks || []))
     |> assign(:user_role, :admin)
     |> assign(:current_team, nil)
     |> assign(:user_token, nil)
     |> assign(:show_team_rosters, true)
     |> assign(:show_timeline_modal, false)
     |> assign(:show_team_order_modal, false)
     |> assign(:show_advanced_modal, false)
     |> assign(:timeline_position, nil)
     |> assign(:show_queue_view, false)
     |> assign(:selected_player_id, nil)
     |> assign(:team_queued_picks, [])
     |> assign(:queued_picks, queued_picks)
     |> assign(:timer_state, timer_state)
     |> assign(:audio_volume, 50)
     |> assign(:audio_muted, false)
     |> assign(:page_title, generate_page_title(draft.name, current_phase, :admin))

    # Initialize ClientTimer hook with current timer state
    socket = if connected?(socket) and timer_state.status == :running do
      # Add missing fields for ClientTimer hook
      enhanced_timer_state = %{
        status: Atom.to_string(timer_state.status),
        remaining_seconds: timer_state.remaining_seconds,
        total_seconds: timer_state.total_seconds,
        current_team_id: timer_state.current_team_id,
        deadline: timer_state.deadline || DateTime.utc_now(),
        server_time: DateTime.utc_now()
      }
      push_event(socket, "timer_state", enhanced_timer_state)
    else
      socket
    end
    
    {:ok, socket, temporary_assigns: [queued_picks: [], team_queued_picks: []]}
  end

  # Mount for organizer token access
  def mount(%{"token" => token}, _session, %{assigns: %{live_action: :organizer}} = socket) do
    case Drafts.get_draft_by_organizer_token(token) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Draft not found")
         |> push_navigate(to: "/")}

      draft ->
        draft = Drafts.get_draft_with_associations!(draft.id)
        players = Drafts.list_available_players(draft.id) || []
        queued_picks = Drafts.list_queued_picks(draft.id)

        if connected?(socket) do
          Phoenix.PubSub.subscribe(AceApp.PubSub, "draft:#{draft.id}")
          Phoenix.PubSub.subscribe(AceApp.PubSub, "draft:#{draft.id}:chat")
        end

        current_phase = get_current_phase(draft)
        timer_state = get_timer_state(draft.id)
        
        socket = 
         socket
         |> assign(:draft, draft)
         |> assign(:players, players)
         |> assign(:filtered_players, players)
         |> assign(:search_term, "")
         |> assign(:selected_role, "all")
         |> assign(:current_phase, current_phase)
         |> assign(:current_pick_order, get_current_pick_order(draft))
         |> assign(:current_pick_number, length(draft.picks || []))
         |> assign(:user_role, :organizer)
         |> assign(:current_team, nil)
         |> assign(:user_token, token)
         |> assign(:show_team_rosters, true)
         |> assign(:show_timeline_modal, false)
         |> assign(:show_team_order_modal, false)
         |> assign(:show_advanced_modal, false)
         |> assign(:timeline_position, nil)
         |> assign(:show_queue_view, false)
         |> assign(:selected_player_id, nil)
         |> assign(:team_queued_picks, [])
         |> assign(:queued_picks, queued_picks)
         |> assign(:timer_state, timer_state)
         |> assign(:audio_volume, 50)
         |> assign(:audio_muted, false)
         |> assign(:page_title, generate_page_title(draft.name, current_phase, :organizer))

        # Initialize ClientTimer hook with current timer state
        socket = if connected?(socket) and timer_state.status == :running do
          # Add missing fields for ClientTimer hook
          enhanced_timer_state = %{
            status: Atom.to_string(timer_state.status),
            remaining_seconds: timer_state.remaining_seconds,
            total_seconds: timer_state.total_seconds,
            current_team_id: timer_state.current_team_id,
            deadline: timer_state.deadline || DateTime.utc_now(),
            server_time: DateTime.utc_now()
          }
          push_event(socket, "timer_state", enhanced_timer_state)
        else
          socket
        end
        
        {:ok, socket, temporary_assigns: [queued_picks: [], team_queued_picks: []]}
    end
  end

  # Mount for spectator token access
  def mount(%{"token" => token}, _session, %{assigns: %{live_action: :spectator}} = socket) do
    case Drafts.get_draft_by_spectator_token(token) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Draft not found")
         |> push_navigate(to: "/")}

      draft ->
        draft = Drafts.get_draft_with_associations!(draft.id)
        players = Drafts.list_available_players(draft.id) || []
        queued_picks = Drafts.list_queued_picks(draft.id)

        if connected?(socket) do
          Phoenix.PubSub.subscribe(AceApp.PubSub, "draft:#{draft.id}")
          Phoenix.PubSub.subscribe(AceApp.PubSub, "draft:#{draft.id}:chat")
        end

        current_phase = get_current_phase(draft)
        timer_state = get_timer_state(draft.id)
        
        socket = 
         socket
         |> assign(:draft, draft)
         |> assign(:players, players)
         |> assign(:filtered_players, players)
         |> assign(:search_term, "")
         |> assign(:selected_role, "all")
         |> assign(:current_phase, current_phase)
         |> assign(:current_pick_order, get_current_pick_order(draft))
         |> assign(:current_pick_number, length(draft.picks || []))
         |> assign(:user_role, :spectator)
         |> assign(:current_team, nil)
         |> assign(:user_token, token)
         |> assign(:show_team_rosters, true)
         |> assign(:show_timeline_modal, false)
         |> assign(:show_team_order_modal, false)
         |> assign(:show_advanced_modal, false)
         |> assign(:timeline_position, nil)
         |> assign(:show_queue_view, false)
         |> assign(:selected_player_id, nil)
         |> assign(:queued_pick, nil)
         |> assign(:queued_picks, queued_picks)
         |> assign(:timer_state, timer_state)
         |> assign(:audio_volume, 50)
         |> assign(:audio_muted, false)
         |> assign(:page_title, generate_page_title(draft.name, current_phase, :spectator))

        # Initialize ClientTimer hook with current timer state
        socket = if connected?(socket) and timer_state.status == :running do
          # Add missing fields for ClientTimer hook
          enhanced_timer_state = %{
            status: Atom.to_string(timer_state.status),
            remaining_seconds: timer_state.remaining_seconds,
            total_seconds: timer_state.total_seconds,
            current_team_id: timer_state.current_team_id,
            deadline: timer_state.deadline || DateTime.utc_now(),
            server_time: DateTime.utc_now()
          }
          push_event(socket, "timer_state", enhanced_timer_state)
        else
          socket
        end
        
        {:ok, socket, temporary_assigns: [queued_picks: [], team_queued_picks: []]}
    end
  end

  # Mount for team captain token access
  def mount(%{"token" => token}, _session, %{assigns: %{live_action: :team}} = socket) do
    case Drafts.get_team_by_captain_token(token) || Drafts.get_team_by_team_member_token(token) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Team not found")
         |> push_navigate(to: "/")}

      team ->
        draft = Drafts.get_draft_with_associations!(team.draft_id)
        players = Drafts.list_available_players(draft.id) || []
        team_queued_picks = Drafts.get_team_queued_picks(draft.id, team.id)
        queued_picks = Drafts.list_queued_picks(draft.id)

        if connected?(socket) do
          Phoenix.PubSub.subscribe(AceApp.PubSub, "draft:#{draft.id}")
          Phoenix.PubSub.subscribe(AceApp.PubSub, "draft:#{draft.id}:chat")
          Phoenix.PubSub.subscribe(AceApp.PubSub, "draft:#{draft.id}:team:#{team.id}:chat")
        end

        current_phase = get_current_phase(draft)
        user_role = if(team.captain_token == token, do: :captain, else: :team_member)
        timer_state = get_timer_state(draft.id)
        
        socket = 
         socket
         |> assign(:draft, draft)
         |> assign(:players, players)
         |> assign(:filtered_players, players)
         |> assign(:search_term, "")
         |> assign(:selected_role, "all")
         |> assign(:current_phase, current_phase)
         |> assign(:current_pick_order, get_current_pick_order(draft))
         |> assign(:current_pick_number, length(draft.picks || []))
         |> assign(:user_role, user_role)
         |> assign(:current_team, team)
         |> assign(:user_token, token)
         |> assign(:show_team_rosters, true)
         |> assign(:show_timeline_modal, false)
         |> assign(:show_team_order_modal, false)
         |> assign(:show_advanced_modal, false)
         |> assign(:timeline_position, nil)
         |> assign(:show_queue_view, false)
         |> assign(:selected_player_id, nil)
         |> assign(:team_queued_picks, team_queued_picks)
         |> assign(:queued_picks, queued_picks)
         |> assign(:timer_state, timer_state)
         |> assign(:audio_volume, 50)
         |> assign(:audio_muted, false)
         |> assign(:page_title, generate_page_title(draft.name, current_phase, user_role, team))

        # Initialize ClientTimer hook with current timer state
        socket = if connected?(socket) and timer_state.status == :running do
          # Add missing fields for ClientTimer hook
          enhanced_timer_state = %{
            status: Atom.to_string(timer_state.status),
            remaining_seconds: timer_state.remaining_seconds,
            total_seconds: timer_state.total_seconds,
            current_team_id: timer_state.current_team_id,
            deadline: timer_state.deadline || DateTime.utc_now(),
            server_time: DateTime.utc_now()
          }
          push_event(socket, "timer_state", enhanced_timer_state)
        else
          socket
        end
        
        {:ok, socket, temporary_assigns: [queued_picks: [], team_queued_picks: []]}
    end
  end


  @impl true
  def handle_event("toggle_team_rosters", _params, socket) do
    {:noreply, assign(socket, :show_team_rosters, !socket.assigns.show_team_rosters)}
  end

  @impl true
  def handle_event("toggle_queue_view", _params, socket) do
    {:noreply, assign(socket, :show_queue_view, !socket.assigns.show_queue_view)}
  end

  # Timeline modal event handlers
  @impl true
  def handle_event("open_timeline_modal", _params, socket) do
    IO.puts("=== OPEN TIMELINE MODAL EVENT ===")
    IO.puts("User role: #{socket.assigns.user_role}")
    
    case socket.assigns.user_role do
      :organizer ->
        IO.puts("Opening timeline modal...")
        
        {:noreply, 
         socket
         |> assign(:show_timeline_modal, true)
         |> assign(:timeline_position, socket.assigns.current_pick_number)}
      
      _ ->
        IO.puts("Access denied for user role: #{socket.assigns.user_role}")
        {:noreply, put_flash(socket, :error, "Access denied")}
    end
  end

  @impl true
  def handle_event("close_timeline_modal", _params, socket) do
    IO.puts("=== CLOSE TIMELINE MODAL EVENT ===")
    IO.puts("User role: #{socket.assigns.user_role}")
    
    {:noreply, 
     socket
     |> assign(:show_timeline_modal, false)
     |> assign(:timeline_position, nil)}
  end

  @impl true
  def handle_event("js-noop", _params, socket) do
    # This prevents the modal content clicks from bubbling to the background
    {:noreply, socket}
  end

  @impl true
  def handle_event("open_team_order_modal", _params, socket) do
    case socket.assigns.user_role do
      :organizer ->
        {:noreply, assign(socket, :show_team_order_modal, true)}
      
      _ ->
        {:noreply, put_flash(socket, :error, "Access denied")}
    end
  end

  @impl true
  def handle_event("close_team_order_modal", _params, socket) do
    {:noreply, assign(socket, :show_team_order_modal, false)}
  end

  # Advanced Options Modal Events
  def handle_event("open_advanced_modal", _params, socket) do
    case socket.assigns.user_role do
      :organizer ->
        {:noreply, assign(socket, :show_advanced_modal, true)}
      _ ->
        {:noreply, put_flash(socket, :error, "Only organizers can access advanced options")}
    end
  end

  def handle_event("close_advanced_modal", _params, socket) do
    {:noreply, assign(socket, :show_advanced_modal, false)}
  end

  def handle_event("preview_draft", _params, socket) do
    IO.puts("=== PREVIEW DRAFT EVENT TRIGGERED ===")
    IO.puts("User role: #{socket.assigns.user_role}")
    IO.puts("Draft ID: #{socket.assigns.draft.id}")
    IO.puts("Draft status: #{socket.assigns.draft.status}")
    
    case socket.assigns.user_role do
      :organizer ->
        draft_id = socket.assigns.draft.id
        
        IO.puts("Starting preview draft for draft #{draft_id}")
        case Drafts.start_preview_draft(draft_id) do
          {:ok, _draft} ->
            IO.puts("Preview draft started successfully!")
            
            {:noreply, 
             socket
             |> assign(:show_advanced_modal, false)
             |> put_flash(:info, "Preview draft started - picks will be made automatically every 2 seconds")}
          {:error, :draft_already_started} ->
            {:noreply, put_flash(socket, :error, "Draft has already been started")}
          {:error, :draft_not_ready} ->
            {:noreply, put_flash(socket, :error, "Draft must be in setup or active status for preview mode")}
          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Could not start preview draft: #{reason}")}
        end
      _ ->
        {:noreply, put_flash(socket, :error, "Only organizers can start preview drafts")}
    end
  end

  @impl true
  def handle_event("reorder_teams_modal", %{"team_order" => team_order}, socket) do
    case socket.assigns.user_role do
      :organizer ->
        # Convert string IDs to integers, filtering out any nil values
        team_ids = team_order
                  |> Enum.filter(&(&1 != nil and &1 != ""))
                  |> Enum.map(&String.to_integer/1)
        
        # Validate we have the correct number of teams
        expected_team_count = length(socket.assigns.draft.teams)
        if length(team_ids) != expected_team_count do
          {:noreply, put_flash(socket, :error, "Invalid team order - expected #{expected_team_count} teams, got #{length(team_ids)}")}
        else
          case Drafts.reorder_teams(socket.assigns.draft.id, team_ids) do
          {:ok, _} ->
            updated_draft = Drafts.get_draft_with_associations!(socket.assigns.draft.id)
            
            # Send system message about team reordering
            Drafts.send_system_message(
              socket.assigns.draft.id, 
              "Organizer reordered the teams",
              %{action: "team_reorder_drag_drop"}
            )
            
            {:noreply, 
             socket
             |> assign(:draft, updated_draft)
             |> put_flash(:info, "Team order updated successfully")}
          
            {:error, _reason} ->
              {:noreply, put_flash(socket, :error, "Failed to reorder teams")}
          end
        end
        
      _ ->
        {:noreply, put_flash(socket, :error, "Access denied")}
    end
  end

  @impl true
  def handle_event("move_team_up", %{"team-id" => team_id}, socket) do
    case socket.assigns.user_role do
      :organizer ->
        team_id = String.to_integer(team_id)
        teams = socket.assigns.draft.teams
        
        # Find the team and its current position
        case Enum.find_index(teams, &(&1.id == team_id)) do
          0 ->
            # Already at the top
            {:noreply, socket}
          
          index when index > 0 ->
            # Swap with the team above
            team_above = Enum.at(teams, index - 1)
            current_team = Enum.at(teams, index)
            
            new_order = teams
                       |> Enum.map(&(&1.id))
                       |> List.replace_at(index - 1, current_team.id)
                       |> List.replace_at(index, team_above.id)
            
            case Drafts.reorder_teams(socket.assigns.draft.id, new_order) do
              {:ok, _} ->
                updated_draft = Drafts.get_draft_with_associations!(socket.assigns.draft.id)
                
                # Send system message about team reordering
                Drafts.send_system_message(
                  socket.assigns.draft.id, 
                  "Organizer moved #{current_team.name} up in pick order",
                  %{action: "team_reorder", team_moved: current_team.name, direction: "up"}
                )
                
                {:noreply, 
                 socket
                 |> assign(:draft, updated_draft)
                 |> put_flash(:info, "#{current_team.name} moved up in pick order")}
              
              {:error, _reason} ->
                {:noreply, put_flash(socket, :error, "Failed to reorder teams")}
            end
          
          nil ->
            {:noreply, put_flash(socket, :error, "Team not found")}
        end
        
      _ ->
        {:noreply, put_flash(socket, :error, "Access denied")}
    end
  end

  @impl true
  def handle_event("move_team_down", %{"team-id" => team_id}, socket) do
    case socket.assigns.user_role do
      :organizer ->
        team_id = String.to_integer(team_id)
        teams = socket.assigns.draft.teams
        
        # Find the team and its current position
        case Enum.find_index(teams, &(&1.id == team_id)) do
          index when index == length(teams) - 1 ->
            # Already at the bottom
            {:noreply, socket}
          
          index when index >= 0 and index < length(teams) - 1 ->
            # Swap with the team below
            current_team = Enum.at(teams, index)
            team_below = Enum.at(teams, index + 1)
            
            new_order = teams
                       |> Enum.map(&(&1.id))
                       |> List.replace_at(index, team_below.id)
                       |> List.replace_at(index + 1, current_team.id)
            
            case Drafts.reorder_teams(socket.assigns.draft.id, new_order) do
              {:ok, _} ->
                updated_draft = Drafts.get_draft_with_associations!(socket.assigns.draft.id)
                
                # Send system message about team reordering
                Drafts.send_system_message(
                  socket.assigns.draft.id, 
                  "Organizer moved #{current_team.name} down in pick order",
                  %{action: "team_reorder", team_moved: current_team.name, direction: "down"}
                )
                
                {:noreply, 
                 socket
                 |> assign(:draft, updated_draft)
                 |> put_flash(:info, "#{current_team.name} moved down in pick order")}
              
              {:error, _reason} ->
                {:noreply, put_flash(socket, :error, "Failed to reorder teams")}
            end
          
          nil ->
            {:noreply, put_flash(socket, :error, "Team not found")}
        end
        
      _ ->
        {:noreply, put_flash(socket, :error, "Access denied")}
    end
  end

  @impl true
  def handle_event("timeline_scrub", %{"value" => position_str}, socket) do
    IO.puts("=== TIMELINE SCRUB EVENT ===")
    IO.puts("User role: #{socket.assigns.user_role}")
    IO.puts("Position: #{position_str}")
    
    case socket.assigns.user_role do
      :organizer ->
        position = String.to_integer(position_str)
        {:noreply, assign(socket, :timeline_position, position)}
      
      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("rollback_to_pick", %{"pick-number" => pick_number_str}, socket) do
    IO.puts("=== ROLLBACK TO PICK EVENT ===")
    IO.puts("User role: #{socket.assigns.user_role}")
    IO.puts("Pick number: #{pick_number_str}")
    
    case socket.assigns.user_role do
      :organizer ->
        pick_number = String.to_integer(pick_number_str)
        
        if pick_number < socket.assigns.current_pick_number do
          case Drafts.rollback_draft_to_pick(
            socket.assigns.draft.id, 
            pick_number, 
            "Organizer", 
            "organizer"
          ) do
            {:ok, _draft} ->
              # Send system message about the rollback action
              Drafts.send_system_message(
                socket.assigns.draft.id, 
                "Organizer rolled back the draft to pick #{pick_number}",
                %{action: "rollback_to_pick", target_pick: pick_number}
              )
              
              {:noreply, 
               socket
               |> assign(:show_timeline_modal, false)
               |> assign(:timeline_position, nil)
               |> put_flash(:info, "Draft rolled back to pick #{pick_number}")}
            
            {:error, reason} ->
              {:noreply, put_flash(socket, :error, "Rollback failed: #{inspect(reason)}")}
          end
        else
          {:noreply, put_flash(socket, :error, "Cannot rollback to current or future pick")}
        end
      
      _ ->
        {:noreply, put_flash(socket, :error, "Access denied")}
    end
  end

  @impl true
  def handle_event("undo_last_pick", _params, socket) do
    IO.puts("=== UNDO LAST PICK EVENT ===")
    IO.puts("User role: #{socket.assigns.user_role}")
    IO.puts("Current pick number: #{socket.assigns.current_pick_number}")
    
    case socket.assigns.user_role do
      :organizer ->
        if socket.assigns.current_pick_number > 0 do
          target_pick = socket.assigns.current_pick_number - 1
          
          case Drafts.rollback_draft_to_pick(
            socket.assigns.draft.id, 
            target_pick, 
            "Organizer", 
            "organizer"
          ) do
            {:ok, _draft} ->
              # Send system message about the undo action
              Drafts.send_system_message(
                socket.assigns.draft.id, 
                "Organizer undid the last pick (rollback to pick #{target_pick})",
                %{action: "undo_last_pick", target_pick: target_pick}
              )
              
              {:noreply, 
               socket
               |> assign(:show_timeline_modal, false)
               |> assign(:timeline_position, nil)
               |> put_flash(:info, "Last pick undone")}
            
            {:error, reason} ->
              {:noreply, put_flash(socket, :error, "Undo failed: #{inspect(reason)}")}
          end
        else
          {:noreply, put_flash(socket, :error, "No picks to undo")}
        end
      
      _ ->
        {:noreply, put_flash(socket, :error, "Access denied")}
    end
  end

  # Timer control event handlers
  @impl true
  def handle_event("pause_timer", _params, socket) do
    case socket.assigns.user_role do
      :organizer ->
        case Drafts.TimerManager.pause_timer(socket.assigns.draft.id) do
          :ok ->
            {:noreply, put_flash(socket, :info, "Timer paused")}
          
          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Failed to pause timer: #{inspect(reason)}")}
        end
      
      _ ->
        {:noreply, put_flash(socket, :error, "Only organizers can control the timer")}
    end
  end

  @impl true
  def handle_event("resume_timer", _params, socket) do
    case socket.assigns.user_role do
      :organizer ->
        case Drafts.TimerManager.resume_timer(socket.assigns.draft.id) do
          :ok ->
            {:noreply, put_flash(socket, :info, "Timer resumed")}
          
          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Failed to resume timer: #{inspect(reason)}")}
        end
      
      _ ->
        {:noreply, put_flash(socket, :error, "Only organizers can control the timer")}
    end
  end

  @impl true
  def handle_event("stop_timer", _params, socket) do
    case socket.assigns.user_role do
      :organizer ->
        case Drafts.TimerManager.stop_timer(socket.assigns.draft.id) do
          :ok ->
            {:noreply, put_flash(socket, :info, "Timer stopped")}
          
          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Failed to stop timer: #{inspect(reason)}")}
        end
      
      _ ->
        {:noreply, put_flash(socket, :error, "Only organizers can control the timer")}
    end
  end

  def handle_event("reset_timer", _params, socket) do
    case socket.assigns.user_role do
      :organizer ->
        draft_id = socket.assigns.draft.id
        timer_duration = socket.assigns.draft.pick_timer_seconds
        
        # Stop the current timer first
        case Drafts.TimerManager.stop_timer(draft_id) do
          :ok ->
            # Get the current team to pick for
            case Drafts.get_next_team_to_pick(socket.assigns.draft) do
              nil ->
                {:noreply, put_flash(socket, :error, "No team is currently picking")}
              
              team ->
                # Start a new timer with full duration but pause it immediately
                case Drafts.TimerManager.start_pick_timer(draft_id, team.id, timer_duration) do
                  {:ok, :timer_started} ->
                    # Pause the timer immediately so it shows full time but is paused
                    case Drafts.TimerManager.pause_timer(draft_id) do
                      :ok ->
                        {:noreply, put_flash(socket, :info, "Timer reset to full time and paused")}
                      
                      {:error, reason} ->
                        {:noreply, put_flash(socket, :error, "Timer reset but failed to pause: #{inspect(reason)}")}
                    end
                  
                  {:error, reason} ->
                    {:noreply, put_flash(socket, :error, "Failed to reset timer: #{inspect(reason)}")}
                end
            end
          
          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Failed to stop timer for reset: #{inspect(reason)}")}
        end
      
      _ ->
        {:noreply, put_flash(socket, :error, "Only organizers can control the timer")}
    end
  end

  @impl true
  def handle_event("cancel_queue_pick", %{"pick-id" => pick_id}, socket) do
    case socket.assigns.current_team do
      nil ->
        {:noreply, put_flash(socket, :error, "No team found")}

      current_team ->
        user_token = socket.assigns.user_token
        draft_id = socket.assigns.draft.id

        case Drafts.cancel_queued_pick_by_id(draft_id, pick_id, current_team.id, user_token) do
          {:ok, _cancelled_pick} ->
            updated_team_queued_picks = Drafts.get_team_queued_picks(draft_id, current_team.id)
            updated_queued_picks = Drafts.list_queued_picks(draft_id)

            {:noreply,
             socket
             |> assign(:team_queued_picks, updated_team_queued_picks)
             |> assign(:queued_picks, updated_queued_picks)
             |> put_flash(:info, "Pick removed from queue")}

          {:error, reason} ->
            error_message =
              case reason do
                :pick_not_found -> "Pick not found in queue"
                :invalid_token -> "You don't have permission to cancel this pick"
                _ -> "Failed to remove pick from queue"
              end

            {:noreply, put_flash(socket, :error, error_message)}
        end
    end
  end

  @impl true
  def handle_event("toggle_team_ready", _params, socket) do
    case socket.assigns.current_team do
      %{id: team_id} ->
        case Drafts.toggle_team_ready(team_id) do
          {:ok, updated_team} ->
            # Broadcast to all connected clients
            Phoenix.PubSub.broadcast(
              AceApp.PubSub,
              "draft:#{socket.assigns.draft.id}",
              {:team_ready_changed, team_id}
            )

            updated_draft = Drafts.get_draft_with_associations!(socket.assigns.draft.id)

            {:noreply,
             socket
             |> assign(:draft, updated_draft)
             |> assign(:current_team, updated_team)
             |> put_flash(:info, "Ready status updated!")}

          {:error, _changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Could not update ready status")}
        end

      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "No team assigned")}
    end
  end

  @impl true
  def handle_event("share_team_link", _params, socket) do
    case socket.assigns.current_team do
      %{team_member_token: token} = _team ->
        team_member_url = "#{AceAppWeb.Endpoint.url()}/drafts/team/#{token}"

        {:noreply,
         socket
         |> push_event("copy-to-clipboard", %{text: team_member_url})
         |> put_flash(
           :info,
           "Team member link copied to clipboard! Share this with your teammates so they can spectate and chat."
         )}

      nil ->
        {:noreply, put_flash(socket, :error, "No team found")}
    end
  end

  @impl true
  def handle_event("start_draft", _params, socket) do
    case socket.assigns.user_role do
      :organizer ->
        case Drafts.start_draft(socket.assigns.draft.id) do
          {:ok, _draft} ->
            # Send system message about draft starting
            {:ok, message} =
              Drafts.send_chat_message(
                socket.assigns.draft.id,
                "system",
                "Draft System",
                "🚀 Draft has started! Good luck to all teams!"
              )

            # Broadcast to all connected clients
            Phoenix.PubSub.broadcast(
              AceApp.PubSub,
              "draft:#{socket.assigns.draft.id}",
              {:draft_started}
            )

            Phoenix.PubSub.broadcast(
              AceApp.PubSub,
              "draft:#{socket.assigns.draft.id}:chat",
              {:new_global_message, message}
            )

            # Send Discord notification via queue
            AceApp.DiscordQueue.enqueue_notification(socket.assigns.draft, :started)

            updated_draft = Drafts.get_draft_with_associations!(socket.assigns.draft.id)

            current_phase = get_current_phase(updated_draft)
            
            {:noreply,
             socket
             |> assign(:draft, updated_draft)
             |> assign(:current_phase, current_phase)
             |> assign(:page_title, generate_page_title(updated_draft.name, current_phase, socket.assigns.user_role, socket.assigns.current_team))
             |> put_flash(:info, "Draft started!")}

          {:error, :teams_not_ready} ->
            {:noreply,
             socket
             |> put_flash(:error, "All teams must be ready before starting the draft")}

          {:error, _reason} ->
            {:noreply,
             socket
             |> put_flash(:error, "Could not start draft")}
        end

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Only organizers can start the draft")}
    end
  end

  @impl true
  def handle_event("stop_draft", _params, socket) do
    case socket.assigns.user_role do
      :organizer ->
        case Drafts.stop_draft(socket.assigns.draft.id) do
          {:ok, _draft} ->
            # Send system message about draft pause
            {:ok, message} =
              Drafts.send_chat_message(
                socket.assigns.draft.id,
                "system",
                "Draft System",
                "⏸️ Draft has been paused by the organizer"
              )

            # Broadcast to all connected clients
            Phoenix.PubSub.broadcast(
              AceApp.PubSub,
              "draft:#{socket.assigns.draft.id}",
              {:draft_stopped}
            )

            Phoenix.PubSub.broadcast(
              AceApp.PubSub,
              "draft:#{socket.assigns.draft.id}:chat",
              {:new_global_message, message}
            )

            # Send Discord notification via queue
            AceApp.DiscordQueue.enqueue_notification(socket.assigns.draft, :paused)

            updated_draft = Drafts.get_draft_with_associations!(socket.assigns.draft.id)
            current_phase = get_current_phase(updated_draft)

            {:noreply,
             socket
             |> assign(:draft, updated_draft)
             |> assign(:current_phase, current_phase)
             |> assign(:page_title, generate_page_title(updated_draft.name, current_phase, socket.assigns.user_role, socket.assigns.current_team))
             |> put_flash(:info, "Draft paused!")}

          {:error, _reason} ->
            {:noreply,
             socket
             |> put_flash(:error, "Could not pause draft")}
        end

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Only organizers can pause the draft")}
    end
  end

  @impl true
  def handle_event("resume_draft", _params, socket) do
    case socket.assigns.user_role do
      :organizer ->
        case Drafts.resume_draft(socket.assigns.draft.id) do
          {:ok, _draft} ->
            # Send system message about draft resume (only once, from the organizer)
            {:ok, message} =
              Drafts.send_chat_message(
                socket.assigns.draft.id,
                "system",
                "Draft System",
                "▶️ Draft has been resumed! Picks continue..."
              )

            # Broadcast to all connected clients
            Phoenix.PubSub.broadcast(
              AceApp.PubSub,
              "draft:#{socket.assigns.draft.id}",
              {:draft_resumed}
            )

            Phoenix.PubSub.broadcast(
              AceApp.PubSub,
              "draft:#{socket.assigns.draft.id}:chat",
              {:new_global_message, message}
            )

            # Send Discord notification via queue
            AceApp.DiscordQueue.enqueue_notification(socket.assigns.draft, :resumed)

            updated_draft = Drafts.get_draft_with_associations!(socket.assigns.draft.id)
            current_phase = get_current_phase(updated_draft)

            {:noreply,
             socket
             |> assign(:draft, updated_draft)
             |> assign(:current_phase, current_phase)
             |> assign(:page_title, generate_page_title(updated_draft.name, current_phase, socket.assigns.user_role, socket.assigns.current_team))
             |> put_flash(:info, "Draft resumed!")}

          {:error, _reason} ->
            {:noreply,
             socket
             |> put_flash(:error, "Could not resume draft")}
        end

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Only organizers can resume the draft")}
    end
  end

  @impl true
  def handle_event("reset_draft", _params, socket) do
    case socket.assigns.user_role do
      :organizer ->
        case Drafts.reset_draft(socket.assigns.draft.id) do
          {:ok, _draft} ->
            # Clear Discord queue of any stuck notifications
            AceApp.DiscordQueue.reset_processing()
            
            # Broadcast to all connected clients
            Phoenix.PubSub.broadcast(
              AceApp.PubSub,
              "draft:#{socket.assigns.draft.id}",
              {:draft_reset}
            )

            updated_draft = Drafts.get_draft_with_associations!(socket.assigns.draft.id)
            updated_players = Drafts.list_available_players(socket.assigns.draft.id)

            {:noreply,
             socket
             |> assign(:draft, updated_draft)
             |> assign(:players, updated_players)
             |> assign(
               :filtered_players,
               filter_players(
                 updated_players,
                 socket.assigns.search_term,
                 socket.assigns.selected_role
               )
             )
             |> assign(:current_phase, get_current_phase(updated_draft))
             |> assign(:current_pick_order, get_current_pick_order(updated_draft))
             |> assign(:page_title, generate_page_title(updated_draft.name, get_current_phase(updated_draft), socket.assigns.user_role, socket.assigns.current_team))
             |> put_flash(:info, "Draft reset to setup!")}

          {:error, _reason} ->
            {:noreply,
             socket
             |> put_flash(:error, "Could not reset draft")}
        end

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Only organizers can reset the draft")}
    end
  end

  @impl true
  def handle_event("search_players", params, socket) do
    search_term = case params do
      %{"search" => term} -> term
      %{"value" => term} -> term
      %{"_target" => ["search"], "search" => term} -> term
      _ -> ""
    end
    
    filtered_players =
      filter_players(socket.assigns.players || [], search_term, socket.assigns.selected_role)

    {:noreply,
     socket
     |> assign(:search_term, search_term)
     |> assign(:filtered_players, filtered_players || [])}
  end

  @impl true
  def handle_event("filter_by_role", %{"role" => role}, socket) do
    filtered_players =
      filter_players(socket.assigns.players || [], socket.assigns.search_term, role)

    {:noreply,
     socket
     |> assign(:selected_role, role)
     |> assign(:filtered_players, filtered_players || [])}
  end

  @impl true
  def handle_event("select_player", %{"player_id" => ""}, socket) do
    # Cancel selection
    {:noreply, assign(socket, :selected_player_id, nil)}
  end

  def handle_event("select_player", %{"player_id" => player_id}, socket) do
    # Just highlight the selected player, don't make the pick yet
    player_id_int = String.to_integer(player_id)
    {:noreply, assign(socket, :selected_player_id, player_id_int)}
  end

  @impl true
  def handle_event("confirm_pick", _params, socket) do
    Logger.info("Draft Room: confirm_pick event received, selected_player_id: #{inspect(socket.assigns.selected_player_id)}")
    
    case socket.assigns.selected_player_id do
      nil ->
        {:noreply, put_flash(socket, :error, "Please select a player first")}

      player_id ->
        draft = socket.assigns.draft
        current_team = socket.assigns.current_team
        user_token = socket.assigns.user_token
        next_team_to_pick = get_current_team_to_pick(draft)

        # Check if user has a team (organizers cannot make picks)
        if is_nil(current_team) do
          {:noreply, put_flash(socket, :error, "Organizers cannot make picks or queue players")}
        else
          # Check if it's this team's turn
          if current_team && next_team_to_pick && current_team.id == next_team_to_pick.id do
          # It's their turn - make the pick immediately
          case make_player_pick(draft.id, current_team.id, player_id) do
            {:ok, _pick} ->
              # Note: The pick broadcast is now handled in Drafts.make_pick function

              updated_draft = Drafts.get_draft_with_associations!(draft.id)
              updated_players = Drafts.list_available_players(draft.id) || []

              {:noreply,
               socket
               |> assign(:draft, updated_draft)
               |> assign(:players, updated_players)
               |> assign(
                 :filtered_players,
                 filter_players(
                   updated_players,
                   socket.assigns.search_term,
                   socket.assigns.selected_role
                 ) || []
               )
               |> assign(:current_pick_order, get_current_pick_order(updated_draft))
               |> assign(:current_phase, get_current_phase(updated_draft))
               |> assign(:page_title, generate_page_title(updated_draft.name, get_current_phase(updated_draft), socket.assigns.user_role, socket.assigns.current_team))
               |> assign(:selected_player_id, nil)
               |> put_flash(:info, "Player picked successfully!")}

            {:error, reason} ->
              error_message =
                case reason do
                  :draft_not_active -> "Draft is not active"
                  :not_team_turn -> "It's not your team's turn"
                  :player_not_available -> "Player is not available"
                  :player_already_picked -> "Player has already been picked"
                  _ -> "Unable to make pick"
                end

              {:noreply, put_flash(socket, :error, error_message)}
          end
        else
          # It's not their turn - queue the pick
          case Drafts.queue_pick(draft.id, current_team.id, player_id, user_token) do
            {:ok, _queued_pick} ->
              # Broadcast that a pick was queued
              Phoenix.PubSub.broadcast(
                AceApp.PubSub,
                "draft:#{draft.id}",
                {:pick_queued, player_id, current_team.id}
              )

              updated_team_queued_picks = Drafts.get_team_queued_picks(draft.id, current_team.id)
              updated_queued_picks = Drafts.list_queued_picks(draft.id)

              {:noreply,
               socket
               |> assign(:selected_player_id, nil)
               |> assign(:team_queued_picks, updated_team_queued_picks)
               |> assign(:queued_picks, updated_queued_picks)
               |> put_flash(:info, "Pick queued! It will be executed when it's your team's turn.")}

            {:error, reason} ->
              error_message =
                case reason do
                  :draft_not_active -> "Draft is not active"
                  :team_not_found -> "Team not found"
                  :invalid_token -> "You don't have permission to make picks for this team"
                  :player_not_available -> "Player is not available"
                  :player_already_queued -> "Player is already in your queue"
                  _ -> "Failed to queue pick: #{inspect(reason)}"
                end

              {:noreply, put_flash(socket, :error, error_message)}
          end
        end
        end
    end
  end

  @impl true
  def handle_event("clear_team_queue", _params, socket) do
    case socket.assigns.current_team do
      nil ->
        {:noreply, put_flash(socket, :error, "No team found")}

      current_team ->
        user_token = socket.assigns.user_token
        draft_id = socket.assigns.draft.id

        case Drafts.clear_team_queue(draft_id, current_team.id, user_token) do
          {:ok, cleared_count} ->
            updated_team_queued_picks = Drafts.get_team_queued_picks(draft_id, current_team.id)
            updated_queued_picks = Drafts.list_queued_picks(draft_id)

            {:noreply,
             socket
             |> assign(:team_queued_picks, updated_team_queued_picks)
             |> assign(:queued_picks, updated_queued_picks)
             |> put_flash(:info, "Cleared #{cleared_count} pick(s) from queue")}

          {:error, reason} ->
            error_message =
              case reason do
                :no_queued_picks -> "No picks in queue to clear"
                :invalid_token -> "You don't have permission to clear the queue"
                _ -> "Failed to clear queue"
              end

            {:noreply, put_flash(socket, :error, error_message)}
        end
    end
  end

  @impl true
  def handle_event("execute_queued_pick", _params, socket) do
    case socket.assigns.current_team do
      nil ->
        {:noreply, put_flash(socket, :error, "No team found")}

      _current_team ->
        case socket.assigns.queued_pick do
          nil ->
            {:noreply, put_flash(socket, :error, "No queued pick to execute")}

          queued_pick ->
            # Set the selected player and then confirm the pick
            socket = assign(socket, :selected_player_id, queued_pick.player_id)
            handle_event("confirm_pick", %{}, socket)
        end
    end
  end

  @impl true
  def handle_event("cancel_queued_pick", _params, socket) do
    case socket.assigns.current_team do
      nil ->
        {:noreply, put_flash(socket, :error, "No team found")}

      current_team ->
        user_token = socket.assigns.user_token
        draft_id = socket.assigns.draft.id

        case Drafts.cancel_queued_pick(draft_id, current_team.id, user_token) do
          {:ok, _cancelled_pick} ->
            updated_queued_picks = Drafts.list_queued_picks(draft_id)

            {:noreply,
             socket
             |> assign(:queued_pick, nil)
             |> assign(:queued_picks, updated_queued_picks)
             |> put_flash(:info, "Queued pick cancelled")}

          {:error, :no_queued_pick} ->
            {:noreply, put_flash(socket, :error, "No queued pick to cancel")}

          {:error, reason} ->
            error_message =
              case reason do
                :invalid_token -> "You don't have permission to cancel this pick"
                _ -> "Failed to cancel queued pick"
              end

            {:noreply, put_flash(socket, :error, error_message)}
        end
    end
  end

  # Audio settings event handlers
  @impl true
  def handle_event("audio_settings_loaded", %{"volume" => volume, "muted" => muted}, socket) do
    {:noreply, 
     socket
     |> assign(:audio_volume, volume)
     |> assign(:audio_muted, muted)}
  end

  @impl true
  def handle_event("audio_settings_updated", %{"volume" => volume, "muted" => muted}, socket) do
    {:noreply,
     socket
     |> assign(:audio_volume, volume) 
     |> assign(:audio_muted, muted)}
  end

  @impl true
  def handle_event("test_audio", _params, socket) do
    # Send test audio event to frontend
    {:noreply, push_event(socket, "test_audio", %{})}
  end

  @impl true
  def handle_event("set_audio_volume", params, socket) do
    # Handle different possible param structures from range input
    volume = case params do
      %{"volume" => vol} -> vol
      %{"value" => vol} -> vol
      vol when is_binary(vol) -> vol
      _ -> 
        IO.inspect(params, label: "Unexpected volume params")
        "50"
    end
    
    volume_int = String.to_integer(volume)
    # Update the audio manager and get the updated settings back
    socket = push_event(socket, "set_audio_volume", %{volume: volume_int})
    {:noreply, assign(socket, :audio_volume, volume_int)}
  end

  @impl true
  def handle_event("toggle_audio_mute", _params, socket) do
    socket = push_event(socket, "toggle_audio_mute", %{})
    {:noreply, socket}
  end

  # Client timer events
  @impl true
  def handle_event("request_timer_sync", _params, socket) do
    # Client is requesting a sync - send current timer state
    case Drafts.get_timer_state(socket.assigns.draft.id) do
      {:ok, timer_state} ->
        sync_data = %{
          remaining_seconds: timer_state.remaining_seconds,
          deadline: timer_state.deadline,
          server_time: DateTime.utc_now()
        }
        socket = push_event(socket, "timer_sync", sync_data)
        {:noreply, socket}
      
      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("timer_client_expired", _params, socket) do
    # Client timer expired - log but server should handle the actual expiration
    Logger.info("Client timer expired for draft #{socket.assigns.draft.id}")
    {:noreply, socket}
  end

  # Timer event handlers
  @impl true
  def handle_info({:timer_tick, timer_state}, socket) do
    # Legacy handler - convert to new timer_state format
    handle_info({:timer_state, timer_state}, socket)
  end
  
  def handle_info({:timer_state, timer_state}, socket) do
    # Send full timer state to client hook for initialization
    socket = push_event(socket, "timer_state", timer_state)
    {:noreply, assign(socket, :timer_state, timer_state)}
  end
  
  def handle_info({:timer_sync, sync_data}, socket) do
    # Send sync data to client hook for drift correction  
    socket = push_event(socket, "timer_sync", sync_data)
    {:noreply, socket}
  end

  @impl true 
  def handle_info({:timer_started, %{team_id: team_id, duration: duration}}, socket) do
    # Check if it's this user's team's turn for audio notification
    socket = if socket.assigns.current_team && socket.assigns.current_team.id == team_id do
      # Play turn notification for the current user's team
      team_name = socket.assigns.current_team.name
      push_event(socket, "play_turn_notification", %{team_name: team_name})
    else
      socket
    end
    
    timer_state = %{
      status: :running, 
      remaining_seconds: duration, 
      total_seconds: duration,
      current_team_id: team_id,
      deadline: DateTime.add(DateTime.utc_now(), duration, :second),
      server_time: DateTime.utc_now()
    }
    
    socket = push_event(socket, "timer_started", timer_state)
    
    {:noreply, 
     socket
     |> assign(:timer_state, timer_state)
     |> put_flash(:info, "Timer started for team #{team_id}: #{duration}s")}
  end

  @impl true
  def handle_info({:timer_warning, %{seconds_remaining: seconds, team_id: team_id}}, socket) do
    # Send audio notification to frontend
    socket = push_event(socket, "play_timer_warning", %{seconds_remaining: seconds})
    
    {:noreply, 
     socket
     |> put_flash(:warn, "#{seconds} seconds remaining for team #{team_id}!")}
  end

  @impl true
  def handle_info({:timer_expired, %{team_id: team_id}}, socket) do
    timer_state = %{status: :expired, remaining_seconds: 0, current_team_id: team_id}
    socket = push_event(socket, "timer_expired", timer_state)
    
    {:noreply, 
     socket
     |> assign(:timer_state, timer_state)
     |> put_flash(:error, "Time expired for team #{team_id}!")}
  end

  @impl true
  def handle_info({:new_global_message, message}, socket) do
    # Forward the message to the chat component
    send_update(AceAppWeb.Components.Chat,
      id: "draft-chat",
      action: :new_global_message,
      message: message
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_team_message, message}, socket) do
    # Forward the message to the chat component
    send_update(AceAppWeb.Components.Chat,
      id: "draft-chat",
      action: :new_team_message,
      message: message
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info({:message_deleted, message_id}, socket) do
    # Forward the deletion to the chat component
    send_update(AceAppWeb.Components.Chat,
      id: "draft-chat",
      action: :message_deleted,
      message_id: message_id
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info({:team_ready_changed, team_id}, socket) do
    # OPTIMIZED: Use incremental update for team ready status instead of full reload
    # Only update the specific team's ready status in the draft.teams
    updated_draft = update(socket, :draft, fn draft ->
      updated_teams = Enum.map(draft.teams, fn team ->
        if team.id == team_id do
          # Fetch just the updated team ready status
          %{team | ready: !team.ready}
        else
          team
        end
      end)
      %{draft | teams: updated_teams}
    end)

    # Update current_team if this user is a captain and it's their team that changed
    updated_current_team =
      if (socket.assigns.user_role == :captain and socket.assigns.current_team) &&
           socket.assigns.current_team.id == team_id do
        Enum.find(updated_draft.teams, &(&1.id == team_id))
      else
        socket.assigns.current_team
      end

    {:noreply,
     socket
     |> assign(:draft, updated_draft)
     |> assign(:current_team, updated_current_team)}
  end

  @impl true
  def handle_info({:draft_started}, socket) do
    # Send audio notification for draft started
    socket = push_event(socket, "play_draft_started", %{})
    
    # Refresh draft state when draft is started
    updated_draft = Drafts.get_draft_with_associations!(socket.assigns.draft.id)

    {:noreply,
     socket
     |> assign(:draft, updated_draft)
     |> assign(:current_phase, get_current_phase(updated_draft))
     |> assign(:page_title, generate_page_title(updated_draft.name, get_current_phase(updated_draft), socket.assigns.user_role, socket.assigns.current_team))}
  end

  @impl true
  def handle_info({:draft_rollback, %{target_pick_number: target_pick_number, draft: rollback_draft}}, socket) do
    # OPTIMIZED: For rollbacks, we need to do full reloads since state could be significantly different
    # However, we can use the provided draft data if available instead of re-querying
    updated_draft = rollback_draft || Drafts.get_draft_with_associations!(socket.assigns.draft.id)
    
    # OPTIMIZED: Only reload players and queued picks on rollback (necessary due to state changes)
    updated_players = Drafts.list_available_players(socket.assigns.draft.id) || []
    updated_queued_picks = Drafts.list_queued_picks(socket.assigns.draft.id)
    
    # Update team queued picks if user has a team
    updated_team_queued_picks = 
      if socket.assigns.current_team do
        Drafts.get_team_queued_picks(socket.assigns.draft.id, socket.assigns.current_team.id)
      else
        []
      end

    {:noreply,
     socket
     |> assign(:draft, updated_draft)
     |> assign(:players, updated_players)
     |> assign(
       :filtered_players,
       filter_players(updated_players, socket.assigns.search_term, socket.assigns.selected_role) ||
         []
     )
     |> assign(:queued_picks, updated_queued_picks)
     |> assign(:team_queued_picks, updated_team_queued_picks)
     |> assign(:current_pick_order, get_current_pick_order(updated_draft))
     |> assign(:current_pick_number, length(updated_draft.picks || []))
     |> assign(:current_phase, get_current_phase(updated_draft))
     |> assign(:page_title, generate_page_title(updated_draft.name, get_current_phase(updated_draft), socket.assigns.user_role, socket.assigns.current_team))
     |> put_flash(:info, "Draft rolled back to pick #{target_pick_number}")}
  end

  @impl true
  def handle_info({:draft_stopped}, socket) do
    # Refresh draft state when draft is stopped/paused
    updated_draft = Drafts.get_draft_with_associations!(socket.assigns.draft.id)

    {:noreply,
     socket
     |> assign(:draft, updated_draft)
     |> assign(:current_phase, get_current_phase(updated_draft))
     |> assign(:page_title, generate_page_title(updated_draft.name, get_current_phase(updated_draft), socket.assigns.user_role, socket.assigns.current_team))}
  end

  @impl true
  def handle_info({:draft_resumed}, socket) do
    # Refresh draft state when draft is resumed
    updated_draft = Drafts.get_draft_with_associations!(socket.assigns.draft.id)

    {:noreply,
     socket
     |> assign(:draft, updated_draft)
     |> assign(:current_phase, get_current_phase(updated_draft))
     |> assign(:page_title, generate_page_title(updated_draft.name, get_current_phase(updated_draft), socket.assigns.user_role, socket.assigns.current_team))}
  end

  @impl true
  def handle_info({:queue_cleared_conflict, team_id, player_id}, socket) do
    # Handle when this team's queued pick was cleared due to conflict
    if socket.assigns.current_team && socket.assigns.current_team.id == team_id do
      updated_team_queued_picks = Drafts.get_team_queued_picks(socket.assigns.draft.id, team_id)
      updated_queued_picks = Drafts.list_queued_picks(socket.assigns.draft.id)
      player = Enum.find(socket.assigns.players, &(&1.id == player_id))

      flash_message =
        if player do
          "Your queued pick (#{player.display_name}) was cleared because another team picked that player."
        else
          "Your queued pick was cleared due to a conflict."
        end

      {:noreply,
       socket
       |> assign(:team_queued_picks, updated_team_queued_picks)
       |> assign(:queued_picks, updated_queued_picks)
       |> put_flash(:info, flash_message)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:draft_reset}, socket) do
    # Refresh all state when draft is reset
    updated_draft = Drafts.get_draft_with_associations!(socket.assigns.draft.id)
    updated_players = Drafts.list_available_players(socket.assigns.draft.id) || []

    {:noreply,
     socket
     |> assign(:draft, updated_draft)
     |> assign(:players, updated_players)
     |> assign(
       :filtered_players,
       filter_players(updated_players, socket.assigns.search_term, socket.assigns.selected_role) ||
         []
     )
     |> assign(:current_pick_order, get_current_pick_order(updated_draft))
     |> assign(:current_phase, get_current_phase(updated_draft))
     |> assign(:page_title, generate_page_title(updated_draft.name, get_current_phase(updated_draft), socket.assigns.user_role, socket.assigns.current_team))}
  end

  @impl true
  def handle_info({:pick_queued, _player_id, _team_id}, socket) do
    # Show notification that a pick was queued
    updated_queued_picks = Drafts.list_queued_picks(socket.assigns.draft.id)

    {:noreply, assign(socket, :queued_picks, updated_queued_picks)}
  end

  @impl true
  def handle_info({:queued_pick_executed, _pick}, socket) do
    # Handle when a queued pick gets automatically executed
    updated_draft = Drafts.get_draft_with_associations!(socket.assigns.draft.id)
    updated_players = Drafts.list_available_players(socket.assigns.draft.id) || []
    updated_queued_picks = Drafts.list_queued_picks(socket.assigns.draft.id)

    {:noreply,
     socket
     |> assign(:draft, updated_draft)
     |> assign(:players, updated_players)
     |> assign(
       :filtered_players,
       filter_players(updated_players, socket.assigns.search_term, socket.assigns.selected_role) ||
         []
     )
     |> assign(:current_pick_order, get_current_pick_order(updated_draft))
     |> assign(:current_phase, get_current_phase(updated_draft))
     |> assign(:page_title, generate_page_title(updated_draft.name, get_current_phase(updated_draft), socket.assigns.user_role, socket.assigns.current_team))
     |> assign(:queued_picks, updated_queued_picks)}
  end

  @impl true
  def handle_info({:pick_made, pick}, socket) do
    # Send audio notification for pick made - get player data safely
    {player_name, player_role} = case pick.player do
      %{display_name: name, preferred_roles: roles} -> 
        # Get primary role for display
        primary_role = case roles do
          [first_role | _] when is_binary(first_role) -> AceApp.LoL.role_display_name(first_role)
          _ -> nil
        end
        {name, primary_role}
      _ -> 
        # Player association not loaded, fetch it
        player = Drafts.get_player!(pick.player_id)
        primary_role = case player.preferred_roles do
          [first_role | _] when is_binary(first_role) -> AceApp.LoL.role_display_name(first_role)
          _ -> nil
        end
        {player.display_name, primary_role}
    end
    socket = push_event(socket, "play_pick_made", %{player_name: player_name})
    
    # Refresh the draft to show the new pick
    updated_draft = Drafts.get_draft_with_associations!(socket.assigns.draft.id)
    updated_players = Drafts.list_available_players(socket.assigns.draft.id) || []
    updated_queued_picks = Drafts.list_queued_picks(socket.assigns.draft.id)
    
    # Update team queued picks if user has a team
    updated_team_queued_picks = 
      if socket.assigns.current_team do
        Drafts.get_team_queued_picks(socket.assigns.draft.id, socket.assigns.current_team.id)
      else
        []
      end
    
    {:noreply,
     socket
     |> assign(:draft, updated_draft)
     |> assign(:players, updated_players)
     |> assign(
       :filtered_players,
       filter_players(updated_players, socket.assigns.search_term, socket.assigns.selected_role) ||
         []
     )
     |> assign(:current_pick_order, get_current_pick_order(updated_draft))
     |> assign(:current_phase, get_current_phase(updated_draft))
     |> assign(:page_title, generate_page_title(updated_draft.name, get_current_phase(updated_draft), socket.assigns.user_role, socket.assigns.current_team))
     |> assign(:queued_picks, updated_queued_picks)
     |> assign(:team_queued_picks, updated_team_queued_picks)}
  end

  # Preview Draft handlers
  def handle_info({:start_preview_picks, draft_id}, socket) do
    IO.puts("=== STARTING PREVIEW PICKS ===")
    IO.puts("Draft ID: #{draft_id}")
    # Schedule the first preview pick
    Process.send_after(self(), {:make_preview_pick, draft_id}, 2000)
    {:noreply, socket}
  end

  def handle_info({:make_preview_pick, draft_id}, socket) do
    IO.puts("=== MAKING PREVIEW PICK ===")
    IO.puts("Draft ID: #{draft_id}")
    
    draft = Drafts.get_draft_with_associations!(draft_id)
    IO.puts("Draft status: #{draft.status}")
    IO.puts("Current turn team ID: #{draft.current_turn_team_id}")
    
    if draft.status == :active do
      current_team = Enum.find(draft.teams, &(&1.id == draft.current_turn_team_id))
      IO.puts("Current team: #{if current_team, do: current_team.name, else: "none"}")
      
      available_players = Drafts.list_available_players(draft_id)
      IO.puts("Available players count: #{length(available_players)}")
      
      if current_team && length(available_players) > 0 do
        # Pick a random player
        random_player = Enum.random(available_players)
        IO.puts("Randomly selected player: #{random_player.display_name}")
        
        # Make the pick (this will trigger normal pick flow)
        case Drafts.make_pick(draft_id, current_team.id, random_player.id, nil, false) do
          {:ok, _pick} ->
            IO.puts("Pick made successfully!")
            # Add a chat message for the preview pick
            Drafts.send_system_message(draft_id, "Preview: #{current_team.name} picked #{random_player.display_name}")
            
            # Schedule next pick if draft is still active (draft completion is handled by make_pick)
            updated_draft = Drafts.get_draft_with_associations!(draft_id)
            if updated_draft.status == :active do
              IO.puts("Scheduling next pick in 2 seconds...")
              Process.send_after(self(), {:make_preview_pick, draft_id}, 2000)
            else
              IO.puts("Draft completed!")
              # Draft is complete - send completion message
              Drafts.send_system_message(draft_id, "Preview draft completed!")
            end
          {:error, reason} ->
            IO.puts("Pick failed: #{inspect(reason)}")
            # If pick fails, try again in 1 second
            Process.send_after(self(), {:make_preview_pick, draft_id}, 1000)
        end
      else
        IO.puts("No available picks - current_team: #{current_team != nil}, available_players: #{length(available_players)}")
        # No available players or no current team - draft might be complete
        Drafts.send_system_message(draft_id, "Preview draft completed - no more picks available!")
      end
    else
      IO.puts("Draft not active, status: #{draft.status}")
    end
    
    {:noreply, socket}
  end

  # Helper functions
  defp filter_players(nil, _search_term, _role), do: []

  defp filter_players(players, search_term, role) when is_list(players) do
    players
    |> filter_by_search(search_term)
    |> filter_by_role(role)
  end

  defp filter_players(_, _search_term, _role), do: []

  defp filter_by_search(nil, _), do: []
  defp filter_by_search(players, ""), do: players

  defp filter_by_search(players, search_term) when is_list(players) and is_binary(search_term) do
    search_lower = String.downcase(search_term)

    Enum.filter(players, fn player ->
      player != nil and player.display_name != nil and
        String.contains?(String.downcase(player.display_name), search_lower)
    end)
  end

  defp filter_by_search(players, _), do: players || []

  defp filter_by_role(nil, _), do: []
  defp filter_by_role(players, "all"), do: players

  defp filter_by_role(players, role) when is_list(players) and is_binary(role) do
    try do
      role_atom = String.to_existing_atom(role)

      Enum.filter(players, fn player ->
        player != nil and player.preferred_roles != nil and
          role_atom in (player.preferred_roles || [])
      end)
    rescue
      ArgumentError -> players
    end
  end

  defp filter_by_role(players, _), do: players || []

  defp get_current_phase(draft) do
    case draft.status do
      :setup ->
        :draft_starting

      :paused ->
        :draft_paused

      :completed ->
        :draft_complete

      :active ->
        picks_count = length(draft.picks)
        # For LoL, standard team size is 5 players
        team_size = 5
        total_picks_needed = team_size * length(draft.teams)

        if picks_count >= total_picks_needed do
          :draft_complete
        else
          :picking
        end
    end
  end

  defp generate_page_title(draft_name, current_phase, user_role, current_team \\ nil) do
    status_text = case current_phase do
      :draft_starting -> "Setup"
      :draft_paused -> "Paused"
      :draft_complete -> "Complete"
      :picking -> "Drafting"
      _ -> "Draft"
    end
    

    role_text = case user_role do
      :organizer -> "Organizer"
      :captain when current_team != nil and not is_nil(current_team.name) -> "#{current_team.name} Captain"
      :captain -> "Captain"
      :team_member when current_team != nil and not is_nil(current_team.name) -> "#{current_team.name} Member"
      :team_member -> "Team Member"
      :spectator -> "Spectator"
      _ -> "Viewer"
    end
    
    "Ace - #{draft_name} (#{status_text}) - #{role_text}"
  end

  defp get_timer_state(draft_id) do
    case Drafts.TimerManager.get_timer_state(draft_id) do
      {:ok, timer_state} -> timer_state
      {:error, _} -> %{status: :stopped, remaining_seconds: 0, current_team_id: nil}
    end
  end

  defp get_timer_team(%{current_team_id: team_id}, draft) when not is_nil(team_id) do
    Enum.find(draft.teams, &(&1.id == team_id))
  end
  
  defp get_timer_team(_, _), do: nil

  defp format_duration(seconds) when is_integer(seconds) do
    cond do
      seconds >= 60 ->
        minutes = div(seconds, 60)
        remaining_seconds = rem(seconds, 60)
        if remaining_seconds == 0 do
          "#{minutes}m"
        else
          "#{minutes}m #{remaining_seconds}s"
        end
      
      true ->
        "#{seconds}s"
    end
  end
  
  defp format_duration(_), do: "0s"

  defp get_current_pick_order(draft) do
    picks_count = length(draft.picks)
    # Calculate current pick number (1-based)
    picks_count + 1
  end

  defp get_current_team_to_pick(draft) do
    Drafts.get_next_team_to_pick(draft)
  end

  defp make_player_pick(draft_id, team_id, player_id) when is_integer(player_id) do
    Logger.info("Draft Room: Making pick for draft #{draft_id}, team #{team_id}, player #{player_id}")
    result = Drafts.make_pick(draft_id, team_id, player_id)
    Logger.info("Draft Room: Pick result: #{inspect(result)}")
    result
  end

  defp make_player_pick(draft_id, team_id, player_id) when is_binary(player_id) do
    player_id_int = String.to_integer(player_id)
    Logger.info("Draft Room: Making pick for draft #{draft_id}, team #{team_id}, player #{player_id_int} (converted from string)")
    result = Drafts.make_pick(draft_id, team_id, player_id_int)
    Logger.info("Draft Room: Pick result: #{inspect(result)}")
    result
  end

  # Get a random champion for visual flair (removed for now since we're not using champions in picks)
  # defp get_random_champion_for_player(_player) do
  #   champions = LoL.list_champions() |> Enum.filter(&(&1.enabled))
  #   Enum.random(champions)
  # end

  # Role helper for the UI
  def role_display_name("all"), do: "All"
  def role_display_name("adc"), do: "ADC"
  def role_display_name(role) when is_atom(role), do: role_display_name(to_string(role))
  def role_display_name(role), do: String.capitalize(role)

  # Safe player name helper
  def safe_player_name(nil), do: "Unknown Player"
  def safe_player_name(%{display_name: nil}), do: "Unknown Player"
  def safe_player_name(%{display_name: ""}), do: "Unknown Player"
  def safe_player_name(%{display_name: name}), do: name
  def safe_player_name(_), do: "Unknown Player"

  # Safe player initial helper
  def safe_player_initial(player) do
    case safe_player_name(player) do
      "Unknown Player" -> "?"
      name -> String.first(name)
    end
  end
end
