defmodule AceAppWeb.ApiController do
  use AceAppWeb, :controller

  alias AceApp.Drafts

  def draft_status_csv(conn, %{"id" => draft_id}) do
    try do
      draft = Drafts.get_draft!(draft_id)
      draft = draft |> AceApp.Repo.preload([picks: [:player, :team]])

      csv_data = generate_draft_picks_csv(draft)

      conn
      |> put_resp_content_type("text/csv")
      |> put_resp_header("cache-control", "no-cache, must-revalidate")
      |> send_resp(200, csv_data)
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Draft not found"})
    end
  end

  def team_info_csv(conn, %{"id" => draft_id}) do
    try do
      draft = Drafts.get_draft!(draft_id)
      teams_with_picks = Drafts.get_teams_with_picks(draft_id)

      csv_data = generate_team_info_csv(draft, teams_with_picks)

      conn
      |> put_resp_content_type("text/csv")
      |> put_resp_header("cache-control", "no-cache, must-revalidate")
      |> send_resp(200, csv_data)
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Draft not found"})
    end
  end

  defp generate_draft_picks_csv(draft) do
    # Header
    header = "Pick Order,Round,Team,Player,Picked At\n"

    # All picks sorted by pick number
    picks_rows =
      draft.picks
      |> Enum.sort_by(& &1.pick_number)
      |> Enum.map_join("\n", fn pick ->
        picked_at = Calendar.strftime(pick.picked_at, "%Y-%m-%d %H:%M:%S")
        "#{pick.pick_number},#{pick.round_number},#{pick.team.name},#{pick.player.display_name},#{picked_at}"
      end)

    header <> picks_rows
  end

  defp generate_team_info_csv(draft, teams_with_picks) do
    next_team = Drafts.get_next_team_to_pick(draft)

    # Header
    header = "Draft Name,Status,Current Turn,Total Teams,Picks Made,Max Picks\n"

    # Draft summary row
    total_picks = length(draft.picks)
    max_picks = length(teams_with_picks) * 5

    draft_row =
      "#{draft.name},#{format_status(draft.status)},#{(next_team && next_team.name) || "Complete"},#{length(teams_with_picks)},#{total_picks},#{max_picks}\n"

    # Team summary header
    team_header = "\nTeam Name,Picks Made,Ready Status,Players\n"

    # Team rows with all their players
    team_rows =
      Enum.map_join(teams_with_picks, "\n", fn team ->
        picks_count = length(team.picks)

        ready_status =
          if draft.status == :setup, do: (team.is_ready && "Ready") || "Not Ready", else: "N/A"

        players_list =
          team.picks
          |> Enum.sort_by(& &1.pick_number)
          |> Enum.map(& &1.player.display_name)
          |> Enum.join("; ")
          |> case do
            "" -> "No picks yet"
            players -> players
          end

        "#{team.name},#{picks_count},#{ready_status},\"#{players_list}\""
      end)

    header <> draft_row <> team_header <> team_rows
  end

  defp format_status(:setup), do: "Setup"
  defp format_status(:active), do: "Active"
  defp format_status(:paused), do: "Paused"
  defp format_status(:completed), do: "Completed"
  defp format_status(status), do: to_string(status)
end
