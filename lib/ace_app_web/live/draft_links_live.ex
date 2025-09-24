defmodule AceAppWeb.DraftLinksLive do
  use AceAppWeb, :live_view

  alias AceApp.Drafts
  alias AceApp.MockDrafts

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Drafts.get_draft_by_organizer_token(token) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Draft not found")
         |> push_navigate(to: "/")}

      draft ->
        teams = Drafts.list_teams(draft.id)
        mock_draft = MockDrafts.get_mock_draft_for_draft(draft.id)

        {:ok,
         socket
         |> assign(:page_title, "Draft Links - #{draft.name}")
         |> assign(:draft, draft)
         |> assign(:teams, teams)
         |> assign(:mock_draft, mock_draft)}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  # Helper functions for generating links
  defp draft_link(draft, :organizer) do
    "/drafts/#{draft.organizer_token}"
  end

  defp draft_link(draft, :spectator) do
    "/drafts/spectator/#{draft.spectator_token}"
  end

  defp team_link(team) do
    "/drafts/team/#{team.captain_token}"
  end

  defp csv_status_link(draft) do
    "/api/drafts/#{draft.id}/status.csv"
  end

  defp csv_team_info_link(draft) do
    "/api/drafts/#{draft.id}/teams.csv"
  end

  # Mock draft helper functions
  defp mock_draft_predraft_link(mock_draft) do
    "/mock-drafts/#{mock_draft.mock_draft_token}/predraft"
  end

  defp mock_draft_live_link(mock_draft) do
    "/mock-drafts/#{mock_draft.mock_draft_token}/live"
  end

  defp mock_draft_leaderboard_link(mock_draft) do
    "/mock-drafts/#{mock_draft.mock_draft_token}/leaderboard"
  end

  # Stream overlay links
  defp stream_overlay_link(draft) do
    "/overlay/#{draft.id}/draft"
  end

  defp stream_overlay_logo_only_link(draft) do
    "/overlay/#{draft.id}/draft?logo_only=true"
  end

  defp stream_current_pick_link(draft) do
    "/overlay/#{draft.id}/current-pick"
  end

  defp stream_roster_link(draft) do
    "/overlay/#{draft.id}/roster"
  end
end
