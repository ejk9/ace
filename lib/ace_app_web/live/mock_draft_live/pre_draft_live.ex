defmodule AceAppWeb.MockDraftLive.PreDraftLive do
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
         |> redirect(to: "/")}

      mock_draft ->
        if mock_draft.predraft_enabled do
          draft = Drafts.get_draft_with_associations!(mock_draft.draft_id)
          players = Drafts.list_available_players(mock_draft.draft_id) || []

          {:ok,
           socket
           |> assign(:mock_draft, mock_draft)
           |> assign(:draft, draft)
           |> assign(:players, players)
           |> assign(:teams, draft.teams)
           |> assign(:submission, nil)
           |> assign(:participant_name, "")
           |> assign(:predicted_picks, %{})
           |> assign(:selected_pick_number, nil)
           |> assign(:page_title, "Mock Draft - #{draft.name}")
           |> assign(:deadline_passed?, deadline_passed?(mock_draft.submission_deadline))}
        else
          {:ok,
           socket
           |> put_flash(:error, "Pre-draft submissions are not enabled for this mock draft")
           |> redirect(to: "/")}
        end
    end
  end

  @impl true
  def handle_params(%{"submission_token" => submission_token}, _uri, socket) do
    case MockDrafts.get_submission_by_token(submission_token) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Submission not found")
         |> push_navigate(to: "/mock-drafts/#{socket.assigns.mock_draft.mock_draft_token}/predraft")}

      submission ->
        if submission.mock_draft_id == socket.assigns.mock_draft.id do
          predicted_picks = MockDrafts.list_predicted_picks_for_submission(submission.id)
          predicted_picks_map = Map.new(predicted_picks, fn pick -> 
            {pick.pick_number, %{team_id: pick.team_id, player_id: pick.predicted_player_id}}
          end)

          {:noreply,
           socket
           |> assign(:submission, submission)
           |> assign(:participant_name, submission.participant_name)
           |> assign(:predicted_picks, predicted_picks_map)
           |> put_flash(:info, "Welcome back #{submission.participant_name}! Continue building your draft prediction.")}
        else
          {:noreply,
           socket
           |> put_flash(:error, "Submission does not belong to this mock draft")
           |> push_navigate(to: "/mock-drafts/#{socket.assigns.mock_draft.mock_draft_token}/predraft")}
        end
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("join_predraft", %{"participant_name" => name}, socket) do
    name = String.trim(name)

    if String.length(name) < 1 do
      {:noreply, put_flash(socket, :error, "Please enter your name")}
    else
      # First check if a submission already exists for this name
      case MockDrafts.find_existing_submission(socket.assigns.mock_draft.id, name) do
        %MockDrafts.MockDraftSubmission{} = existing_submission ->
          # Redirect to existing submission
          personal_url = "/mock-drafts/#{socket.assigns.mock_draft.mock_draft_token}/predraft/#{existing_submission.submission_token}"
          
          {:noreply,
           socket
           |> put_flash(:info, "Welcome back #{name}! Continuing your previous draft prediction.")
           |> push_navigate(to: personal_url)}

        nil ->
          # Create new submission
          case MockDrafts.create_submission(socket.assigns.mock_draft.id, name) do
            {:ok, submission} ->
              # Redirect to the personalized URL with submission token
              personal_url = "/mock-drafts/#{socket.assigns.mock_draft.mock_draft_token}/predraft/#{submission.submission_token}"
              
              {:noreply,
               socket
               |> put_flash(:info, "Welcome #{name}! Bookmark this page to return to your draft prediction.")
               |> push_navigate(to: personal_url)}

            {:error, changeset} ->
              # Debug the changeset
              require Logger
              Logger.debug("Changeset errors: #{inspect(changeset.errors)}")
              
              error_msg = 
                cond do
                  # Check for unique constraint violation
                  Enum.any?(changeset.errors, fn 
                    {:mock_draft_id_participant_name, {"has already been taken", _}} -> true
                    {_, {"has already been taken", _}} -> true
                    _ -> false
                  end) ->
                    "That name is already taken. Please choose a different name."
                  
                  # Check for any participant_name error
                  changeset.errors[:participant_name] ->
                    {msg, _} = changeset.errors[:participant_name]
                    "Name #{msg}"
                  
                  # Check if it's a database constraint error (fallback)
                  changeset.errors == [] ->
                    "That name is already taken. Please choose a different name."
                  
                  # Default error
                  true ->
                    "Failed to join mock draft. Please try again."
                end

              {:noreply, put_flash(socket, :error, error_msg)}
          end
      end
    end
  end

  @impl true
  def handle_event("update_prediction", %{"pick_number" => pick_str, "team_id" => team_str, "player_id" => player_str}, socket) do
    with {pick_number, ""} <- Integer.parse(pick_str),
         {team_id, ""} <- Integer.parse(team_str),
         {player_id, ""} <- Integer.parse(player_str),
         %{submission: submission} when not is_nil(submission) <- socket.assigns do

      case MockDrafts.upsert_predicted_pick(submission.id, pick_number, team_id, player_id) do
        {:ok, _predicted_pick} ->
          # Update local state
          predicted_picks = Map.put(socket.assigns.predicted_picks, pick_number, %{
            team_id: team_id,
            player_id: player_id
          })

          {:noreply,
           socket
           |> assign(:predicted_picks, predicted_picks)
           |> put_flash(:info, "Prediction updated for pick ##{pick_number}")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to save prediction. Please try again.")}
      end
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Invalid prediction data")}
    end
  end

  @impl true
  def handle_event("remove_prediction", %{"pick_number" => pick_str}, socket) do
    with {pick_number, ""} <- Integer.parse(pick_str),
         %{predicted_picks: predicted_picks} <- socket.assigns do

      # Remove from local state
      predicted_picks = Map.delete(predicted_picks, pick_number)

      {:noreply,
       socket
       |> assign(:predicted_picks, predicted_picks)
       |> assign(:selected_pick_number, nil)
       |> put_flash(:info, "Prediction removed for pick ##{pick_number}")}
    else
      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("submit_complete_draft", _params, socket) do
    case socket.assigns.submission do
      nil ->
        {:noreply, put_flash(socket, :error, "You must join the mock draft first")}

      submission ->
        if submission.is_submitted do
          {:noreply, put_flash(socket, :error, "You have already submitted your draft")}
        else
          total_picks_needed = length(socket.assigns.teams) * 5
          current_picks = map_size(socket.assigns.predicted_picks)

          if current_picks < total_picks_needed do
            {:noreply, put_flash(socket, :error, "Please complete all #{total_picks_needed} picks before submitting")}
          else
            case MockDrafts.submit_complete_draft(submission.id) do
              {:ok, _submission} ->
                {:noreply,
                 socket
                 |> assign(:submission, %{submission | is_submitted: true, submitted_at: DateTime.utc_now()})
                 |> put_flash(:success, "Draft submitted successfully! Watch the real draft to see how you did.")}

              {:error, _changeset} ->
                {:noreply, put_flash(socket, :error, "Failed to submit draft. Please try again.")}
            end
          end
        end
    end
  end

  @impl true
  def handle_event("save_progress", _params, socket) do
    {:noreply, put_flash(socket, :info, "Progress saved automatically")}
  end

  @impl true
  def handle_event("select_pick_slot", params, socket) do
    pick_str = params["pick_number"] || params["pick-number"]
    case Integer.parse(pick_str) do
      {pick_number, ""} ->
        {:noreply, assign(socket, :selected_pick_number, pick_number)}
      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_player", params, socket) do
    player_id_str = params["player_id"] || params["player-id"]
    with {player_id, ""} <- Integer.parse(player_id_str),
         %{selected_pick_number: pick_number, submission: submission} when not is_nil(pick_number) and not is_nil(submission) <- socket.assigns,
         player when not is_nil(player) <- Enum.find(socket.assigns.players, &(&1.id == player_id)) do

      # Find the team for this pick
      team_index = rem(pick_number - 1, 2)
      team = Enum.at(socket.assigns.teams, team_index)

      case MockDrafts.upsert_predicted_pick(submission.id, pick_number, team.id, player_id) do
        {:ok, _predicted_pick} ->
          # Update local state
          predicted_picks = Map.put(socket.assigns.predicted_picks, pick_number, %{
            team_id: team.id,
            player_id: player_id
          })

          {:noreply,
           socket
           |> assign(:predicted_picks, predicted_picks)
           |> assign(:selected_pick_number, nil)
           |> put_flash(:info, "#{player.display_name} assigned to pick ##{pick_number}")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to assign player. Please try again.")}
      end
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Please select a pick slot first")}
    end
  end

  @impl true
  def handle_event("cancel_selection", _params, socket) do
    {:noreply, assign(socket, :selected_pick_number, nil)}
  end

  # Helper functions

  defp deadline_passed?(nil), do: false
  defp deadline_passed?(deadline) do
    DateTime.compare(DateTime.utc_now(), deadline) == :gt
  end

  defp calculate_pick_number(team_index, round) do
    # Snake draft pick calculation
    teams_count = 10 # This should be dynamic based on actual teams
    
    if rem(round, 2) == 1 do
      # Odd round: normal order (1, 2, 3, ...)
      (round - 1) * teams_count + team_index + 1
    else
      # Even round: reverse order (..., 3, 2, 1)
      (round - 1) * teams_count + (teams_count - team_index)
    end
  end

  defp get_pick_for_team_and_round(team_index, round) do
    calculate_pick_number(team_index, round)
  end

  defp format_deadline(nil), do: "No deadline set"
  defp format_deadline(deadline) do
    deadline
    |> DateTime.to_date()
    |> Date.to_string()
  end
end