defmodule AceAppWeb.MockDraftLive.LeaderboardLive do
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
        # Load draft to check status
        draft = Drafts.get_draft!(mock_draft.draft_id)
        
        # Load both track data
        submissions = MockDrafts.list_submissions_for_mock_draft(mock_draft.id)
        participants = MockDrafts.list_participants_for_mock_draft(mock_draft.id)

        {:ok,
         socket
         |> assign(:page_title, "Mock Draft Leaderboard")
         |> assign(:mock_draft, mock_draft)
         |> assign(:draft, draft)
         |> assign(:submissions, submissions)
         |> assign(:participants, participants)
         |> assign(:active_track, "track1")}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("switch_track", %{"track" => track}, socket) do
    {:noreply, assign(socket, :active_track, track)}
  end
end