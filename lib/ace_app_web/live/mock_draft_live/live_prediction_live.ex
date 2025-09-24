defmodule AceAppWeb.MockDraftLive.LivePredictionLive do
  use AceAppWeb, :live_view

  alias AceApp.MockDrafts
  alias AceApp.Drafts

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case MockDrafts.get_mock_draft_by_token(token) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Mock draft not found")
         |> push_navigate(to: "/")}

      mock_draft ->
        # Load draft data
        draft = Drafts.get_draft!(mock_draft.draft_id)
        teams = Drafts.list_teams(draft.id)
        players = Drafts.list_players(draft.id)
        participants = MockDrafts.list_participants_for_mock_draft(mock_draft.id)

        # Subscribe to draft events for real-time updates
        if connected?(socket) do
          Phoenix.PubSub.subscribe(AceApp.PubSub, "draft:#{draft.id}")
        end

        {:ok,
         socket
         |> assign(:page_title, "Live Mock Draft Predictions")
         |> assign(:mock_draft, mock_draft)
         |> assign(:draft, draft)
         |> assign(:teams, teams)
         |> assign(:players, players)
         |> assign(:participants, participants)
         |> assign(:current_participant, nil)
         |> assign(:participant_name, "")
         |> assign(:show_join_form, true)
         |> assign(:current_prediction, nil),
         # Configure temporary assigns for large datasets to improve performance
         temporary_assigns: [participants: []]}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("join_as_participant", %{"participant" => %{"name" => name}}, socket) do
    case MockDrafts.create_participant(socket.assigns.mock_draft.id, name) do
      {:ok, participant} ->
        # Update participants list
        participants = MockDrafts.list_participants_for_mock_draft(socket.assigns.mock_draft.id)
        # Check if participant has prediction for current pick
        current_prediction = get_current_prediction(participant.id, socket.assigns.draft)
        
        {:noreply,
         socket
         |> assign(:current_participant, participant)
         |> assign(:participants, participants)
         |> assign(:current_prediction, current_prediction)
         |> assign(:show_join_form, false)
         |> put_flash(:info, "Successfully joined as #{name}!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Unable to join. Please try a different name.")}
    end
  end

  @impl true
  def handle_event("make_prediction", %{"player_id" => player_id}, socket) do
    if socket.assigns.current_participant do
      current_pick = get_current_pick_number(socket.assigns.draft)
      participant_id = socket.assigns.current_participant.id
      
      case MockDrafts.create_live_prediction(participant_id, current_pick, String.to_integer(player_id)) do
        {:ok, prediction} ->
          # Update participant data to reflect new prediction
          updated_participant = MockDrafts.get_participant!(participant_id)
          player = Enum.find(socket.assigns.players, &(&1.id == String.to_integer(player_id)))
          
          # Update the prediction with predicted_at timestamp
          prediction
          |> MockDrafts.MockDraftPrediction.changeset(%{predicted_at: DateTime.utc_now()})
          |> AceApp.Repo.update()
          
          {:noreply,
           socket
           |> assign(:current_participant, updated_participant)
           |> assign(:current_prediction, prediction |> AceApp.Repo.preload(:predicted_player))
           |> put_flash(:info, "Predicted #{player.display_name} for pick ##{current_pick}!")}
           
        {:error, changeset} ->
          error_msg = case changeset.errors do
            [{:participant_id, _}] -> 
              "You've already made a prediction for this pick"
            _ -> 
              "Unable to make prediction. Please try again."
          end
          {:noreply, put_flash(socket, :error, error_msg)}
      end
    else
      {:noreply, put_flash(socket, :error, "Please join as a participant first")}
    end
  end

  @impl true
  def handle_event("show_join_form", _params, socket) do
    {:noreply, assign(socket, :show_join_form, true)}
  end

  @impl true
  def handle_info({:pick_made, pick}, socket) do
    # Score predictions for this pick
    MockDrafts.score_pick_predictions(pick)
    
    # OPTIMIZED: Use incremental update for draft instead of full reload
    # Only update the draft.picks field with the new pick
    updated_draft = update(socket, :draft, fn draft ->
      %{draft | picks: draft.picks ++ [pick]}
    end)
    
    # OPTIMIZED: Only reload participants if scoring actually changed scores
    # Check if current participant's score might have changed
    current_pick_number = pick.pick_number
    participants = 
      if socket.assigns.current_participant do
        # Check if current participant had a prediction for this pick
        case MockDrafts.get_live_prediction(socket.assigns.current_participant.id, current_pick_number) do
          nil -> 
            # No prediction, scores didn't change for current participant
            # Use incremental update to avoid full reload
            socket.assigns.participants
          _prediction ->
            # Had prediction, scores changed - need to reload participants
            MockDrafts.list_participants_for_mock_draft(socket.assigns.mock_draft.id)
        end
      else
        # No current participant, but other participants might have scores updated
        # For now, we'll reload participants when any pick is made to ensure accuracy
        # Future optimization: add count_predictions_for_pick/1 function to MockDrafts
        MockDrafts.list_participants_for_mock_draft(socket.assigns.mock_draft.id)
      end
    
    # OPTIMIZED: Only update current participant if they exist and had score changes
    updated_current_participant = 
      if socket.assigns.current_participant do
        current_pick_number = pick.pick_number
        case MockDrafts.get_live_prediction(socket.assigns.current_participant.id, current_pick_number) do
          nil -> 
            # No prediction for this pick, participant data unchanged
            socket.assigns.current_participant
          _prediction ->
            # Had prediction, score might have changed - reload participant
            MockDrafts.get_participant!(socket.assigns.current_participant.id)
        end
      else
        nil
      end
    
    # Clear current prediction since pick is made
    updated_current_prediction = 
      if socket.assigns.current_participant do
        get_current_prediction(socket.assigns.current_participant.id, updated_draft)
      else
        nil
      end

    {:noreply,
     socket
     |> assign(:draft, updated_draft)
     |> assign(:participants, participants)
     |> assign(:current_participant, updated_current_participant)
     |> assign(:current_prediction, updated_current_prediction)
     |> put_flash(:info, "Pick #{pick.pick_number} made! Scores updated.")}
  end

  @impl true
  def handle_info({:draft_status_changed, _draft}, socket) do
    # Refresh draft state when status changes
    updated_draft = Drafts.get_draft!(socket.assigns.draft.id)
    
    {:noreply,
     socket
     |> assign(:draft, updated_draft)
     |> put_flash(:info, "Draft status updated to #{String.capitalize(updated_draft.status)}")}
  end

  # Handle other draft events
  @impl true
  def handle_info(_event, socket) do
    {:noreply, socket}
  end

  # Helper functions
  defp get_current_pick_number(draft) do
    case draft.status do
      "active" -> 
        Drafts.get_current_pick_number(draft.id) + 1  # Next pick to be made
      _ -> 
        1
    end
  end

  defp get_current_team(teams, draft) do
    case draft.status do
      "active" ->
        Drafts.get_next_team_to_pick(draft) || hd(teams)
      _ ->
        hd(teams)
    end
  end

  defp get_current_prediction(participant_id, draft) do
    current_pick = get_current_pick_number(draft)
    
    case MockDrafts.get_live_prediction(participant_id, current_pick) do
      nil -> nil
      prediction -> prediction |> AceApp.Repo.preload(:predicted_player)
    end
  end
end