defmodule AceAppWeb.ScreenshotController do
  use AceAppWeb, :controller

  @doc """
  Renders the player popup for screenshot capture.
  This endpoint provides a clean version of the popup without the full draft room UI.
  """
  def player_popup(conn, params) do
    # Extract player data from query params
    player_data = %{
      player_name: params["player_name"] || "Unknown Player",
      team_name: params["team_name"] || "Unknown Team", 
      team_color: params["team_color"] || "bg-blue-500",
      player_role: params["player_role"] || "",
      champion_name: params["champion_name"] || "",
      champion_title: params["champion_title"] || "",
      champion_image: params["champion_image"] || "",
      skin_name: params["skin_name"] || "",
      pick_number: params["pick_number"] || "1",
      round_number: params["round_number"] || "1"
    }

    conn
    |> put_root_layout(false)  # No root layout
    |> put_layout(false)  # No layout for clean screenshot
    |> render(:player_popup, player_data: player_data)
  end
end