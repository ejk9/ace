defmodule AceAppWeb.MockDraftLive.ParticipantViewLive do
  use AceAppWeb, :live_view

  alias AceApp.MockDrafts
  alias AceApp.Drafts

  @impl true
  def mount(%{"token" => mock_draft_token, "participant_token" => participant_token}, _session, socket) do
    case MockDrafts.get_mock_draft_by_token(mock_draft_token) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Mock draft not found")
         |> push_navigate(to: "/")}

      mock_draft ->
        case MockDrafts.get_participant_by_token(participant_token) do
          nil ->
            {:ok,
             socket
             |> put_flash(:error, "Participant not found")
             |> push_navigate(to: "/mock-drafts/#{mock_draft_token}/leaderboard")}

          participant ->
            if participant.mock_draft_id == mock_draft.id do
              # Load participant's predictions
              predictions = MockDrafts.list_predictions_for_participant(participant.id)
              draft = Drafts.get_draft_with_associations!(mock_draft.draft_id)
              players = Drafts.list_available_players(mock_draft.draft_id) || []

              {:ok,
               socket
               |> assign(:page_title, "#{participant.display_name}'s Predictions")
               |> assign(:mock_draft, mock_draft)
               |> assign(:participant, participant)
               |> assign(:predictions, predictions)
               |> assign(:draft, draft)
               |> assign(:players, players)}
            else
              {:ok,
               socket
               |> put_flash(:error, "Participant does not belong to this mock draft")
               |> push_navigate(to: "/mock-drafts/#{mock_draft_token}/leaderboard")}
            end
        end
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  defp get_player_by_id(players, player_id) do
    Enum.find(players, &(&1.id == player_id))
  end
end