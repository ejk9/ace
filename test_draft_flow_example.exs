defmodule DraftFlowExample do
  use AceAppWeb.ConnCase
  import Phoenix.LiveViewTest

  test "complete draft setup flow", %{conn: conn} do
    # Stage 1: Basic Info
    {:ok, view, html} = live(conn, "/drafts/new")
    assert html =~ "Create New Draft"

    # Fill out basic info
    view
    |> form("form",
      draft: %{
        name: "Tournament Final",
        format: :snake,
        pick_timer_seconds: 120
      }
    )
    |> render_submit()

    # Stage 2: Teams Setup
    html = render(view)
    assert html =~ "Setup Teams"

    # Add Team 1
    view
    |> form("form", team: %{name: "Cloud9"})
    |> render_submit()

    # Add Team 2  
    view
    |> form("form", team: %{name: "Team Liquid"})
    |> render_submit()

    # Proceed to players
    view
    |> element("button", "Next: Add Players")
    |> render_click()

    # Stage 3: Players Setup
    html = render(view)
    assert html =~ "Add Players"
    assert html =~ "Players needed:</strong> 10"

    # Add 10 players (5 per team)
    players = [
      {"Blaber", ["jungle"]},
      {"Jensen", ["mid"]},
      {"Berserker", ["adc"]},
      {"Vulcan", ["support"]},
      {"Fudge", ["top"]},
      {"Santorin", ["jungle"]},
      {"Bjergsen", ["mid"]},
      {"Hans sama", ["adc"]},
      {"CoreJJ", ["support"]},
      {"Impact", ["top"]}
    ]

    for {name, roles} <- players do
      view
      |> form("form",
        player: %{
          display_name: name,
          preferred_roles: roles
        }
      )
      |> render_submit()
    end

    # Finalize the draft
    view
    |> element("button", "Finalize Draft")
    |> render_click()

    # Stage 4: Complete
    html = render(view)
    assert html =~ "Draft Created Successfully!"
    assert html =~ "Organizer (Admin) Link"
    assert html =~ "Team Captain Links"
    assert html =~ "Cloud9:"
    assert html =~ "Team Liquid:"
    assert html =~ "Spectator Link"
    assert html =~ "Go to Draft Admin"
  end
end
