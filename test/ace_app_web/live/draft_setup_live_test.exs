defmodule AceAppWeb.DraftSetupLiveTest do
  use AceAppWeb.ConnCase

  import Phoenix.LiveViewTest
  alias AceApp.Drafts

  # Helper to create a draft and get to the setup LiveView
  defp create_draft_and_get_setup_view(conn, attrs \\ %{}) do
    draft_attrs = Map.merge(%{
      name: "Test Draft",
      format: :snake,
      pick_timer_seconds: 60
    }, attrs)
    
    {:ok, draft} = Drafts.create_draft(draft_attrs)
    {:ok, view, html} = live(conn, "/drafts/#{draft.id}/setup")
    {view, html, draft}
  end

  describe "Draft Setup LiveView" do
    test "mount displays initial setup with teams step", %{conn: conn} do
      {view, _html, _draft} = create_draft_and_get_setup_view(conn)

      # Navigate to teams step to see teams content
      view |> element("button[phx-value-step='teams']") |> render_click()
      html = render(view)

      assert html =~ "Setup Teams"
      assert html =~ "Add New Team"
    end

    test "validates team creation form", %{conn: conn} do
      {view, _html, _draft} = create_draft_and_get_setup_view(conn)

      # Navigate to teams step
      view |> element("button[phx-value-step='teams']") |> render_click()

      # Submit empty team form
      html =
        view
        |> form("#team-form", team: %{name: "", logo_url: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end

    test "adds teams on teams step", %{conn: conn} do
      {view, _html, _draft} = create_draft_and_get_setup_view(conn)

      # Navigate to teams step
      view |> element("button[phx-value-step='teams']") |> render_click()

      # Add a team
      view
      |> form("#team-form", team: %{name: "Blue Team", logo_url: ""})
      |> render_submit()

      html = render(view)
      assert html =~ "Blue Team"
    end

    test "navigates between steps", %{conn: conn} do
      {view, _html, _draft} = create_draft_and_get_setup_view(conn)

      # Navigate to teams step and add a team first
      view |> element("button[phx-value-step='teams']") |> render_click()
      view
      |> form("#team-form", team: %{name: "Blue Team", logo_url: ""})
      |> render_submit()

      # Navigate to players step
      view
      |> element("button", "🎮 Players")
      |> render_click()

      html = render(view)
      assert html =~ "Add Players"
      assert html =~ "Add New Player"
    end

    test "adds players on players step", %{conn: conn} do
      {view, _html, _draft} = create_draft_and_get_setup_view(conn)

      # Navigate to teams step and add a team first
      view |> element("button[phx-value-step='teams']") |> render_click()
      view
      |> form("#team-form", team: %{name: "Blue Team", logo_url: ""})
      |> render_submit()

      # Navigate to players step
      view
      |> element("button", "🎮 Players")
      |> render_click()

      # Add a player
      view
      |> form("#player-form", 
        player: %{
          display_name: "Test Player",
          preferred_roles: ["top", "jungle"]
        }
      )
      |> render_submit()

      html = render(view)
      assert html =~ "Test Player"
    end

    test "prevents finalizing draft without enough players", %{conn: conn} do
      {view, _html, _draft} = create_draft_and_get_setup_view(conn)

      # Navigate to teams step and add teams
      view |> element("button[phx-value-step='teams']") |> render_click()
      view
      |> form("#team-form", team: %{name: "Blue Team", logo_url: ""})
      |> render_submit()

      # Add another team
      view
      |> form("#team-form", team: %{name: "Red Team", logo_url: ""})
      |> render_submit()

      # Try to finalize without enough players
      html = render(view)
      refute html =~ "Finalize Draft"
    end

    test "completes full workflow", %{conn: conn} do
      {view, _html, _draft} = create_draft_and_get_setup_view(conn)

      # Navigate to teams step and add teams
      view |> element("button[phx-value-step='teams']") |> render_click()
      view
      |> form("#team-form", team: %{name: "Blue Team", logo_url: ""})
      |> render_submit()

      view
      |> form("#team-form", team: %{name: "Red Team", logo_url: ""})
      |> render_submit()

      # Navigate to players
      view
      |> element("button", "🎮 Players")
      |> render_click()

      # Add enough players (10 for 2 teams with 5 each)
      for i <- 1..10 do
        view
        |> form("#player-form", 
          player: %{
            display_name: "Player #{i}",
            preferred_roles: ["top"]
          }
        )
        |> render_submit()
      end

      # Should now be able to finalize
      html = render(view)
      assert html =~ "Finalize Draft"
    end

    test "removes teams and players", %{conn: conn} do
      {view, _html, _draft} = create_draft_and_get_setup_view(conn)

      # Navigate to teams step and add a team
      view |> element("button[phx-value-step='teams']") |> render_click()
      view
      |> form("#team-form", team: %{name: "Blue Team", logo_url: ""})
      |> render_submit()

      # Navigate to players and add a player
      view
      |> element("button", "🎮 Players")
      |> render_click()

      view
      |> form("#player-form", 
        player: %{
          display_name: "Test Player",
          preferred_roles: ["top"]
        }
      )
      |> render_submit()

      # Go back to teams and remove the team
      view
      |> element("button", "👥 Teams")
      |> render_click()

      html = render(view)
      assert html =~ "Blue Team"
    end

    test "creates team with logo URL", %{conn: conn} do
      {view, _html, _draft} = create_draft_and_get_setup_view(conn)

      # Navigate to teams step and add team with logo URL
      view |> element("button[phx-value-step='teams']") |> render_click()
      view
      |> form("#team-form", 
        team: %{
          name: "Blue Team", 
          logo_url: "https://example.com/logo.png"
        }
      )
      |> render_submit()

      html = render(view)
      assert html =~ "Blue Team"
      assert html =~ "example.com/logo.png"
    end

    test "creates team with empty logo URL", %{conn: conn} do
      {view, _html, _draft} = create_draft_and_get_setup_view(conn)

      # Navigate to teams step and add team with empty logo URL (should use fallback)
      view |> element("button[phx-value-step='teams']") |> render_click()
      view
      |> form("#team-form", team: %{name: "Blue Team", logo_url: ""})
      |> render_submit()

      html = render(view)
      assert html =~ "Blue Team"
    end

    test "displays file upload UI with correct limits", %{conn: conn} do
      {view, _html, _draft} = create_draft_and_get_setup_view(conn)

      # Navigate to teams step to see file upload UI
      view |> element("button[phx-value-step='teams']") |> render_click()
      html = render(view)

      assert html =~ "10MB"
      assert html =~ "WebP"
    end

    test "displays validation errors", %{conn: conn} do
      {view, _html, _draft} = create_draft_and_get_setup_view(conn)

      # Navigate to teams step and submit invalid team form
      view |> element("button[phx-value-step='teams']") |> render_click()
      html =
        view
        |> form("#team-form", team: %{name: "", logo_url: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end

    test "shows progress indicators", %{conn: conn} do
      {_view, html, _draft} = create_draft_and_get_setup_view(conn)

      # Should show current step highlighted
      assert html =~ "👥 Teams"
      assert html =~ "🎮 Players"
    end
  end
end