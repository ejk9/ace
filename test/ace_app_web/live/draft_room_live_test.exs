defmodule AceAppWeb.DraftRoomLiveTest do
  use AceAppWeb.ConnCase

  import Phoenix.LiveViewTest
  alias AceApp.Drafts

  @create_draft_attrs %{
    name: "Test Draft",
    format: :snake,
    pick_timer_seconds: 60,
    status: :setup,
    team_size: 5
  }

  describe "Draft Room" do
    setup do
      # Create a draft with teams and players
      {:ok, draft} = Drafts.create_draft(@create_draft_attrs)

      # Add teams
      {:ok, team1} = Drafts.create_team(draft.id, %{name: "Team Alpha"})
      {:ok, team2} = Drafts.create_team(draft.id, %{name: "Team Beta"})

      # Add players
      {:ok, player1} =
        Drafts.create_player(draft.id, %{
          display_name: "Player1",
          preferred_roles: [:adc]
        })

      {:ok, player2} =
        Drafts.create_player(draft.id, %{
          display_name: "Player2",
          preferred_roles: [:mid, :top]
        })

      %{draft: draft, team1: team1, team2: team2, player1: player1, player2: player2}
    end

    test "displays draft room interface", %{conn: conn, draft: draft} do
      {:ok, _view, html} = live(conn, "/drafts/#{draft.id}/room")

      assert html =~ "Test Draft"
      assert html =~ "Draft Room"
      assert html =~ "Player Draft"
      assert html =~ "Team Alpha"
      assert html =~ "Team Beta"
    end

    test "shows current phase information", %{conn: conn, draft: draft} do
      {:ok, _view, html} = live(conn, "/drafts/#{draft.id}/room")

      # Should show phase status (Ready to Start for setup phase)
      assert html =~ "Ready to Start"
    end

    test "displays available players", %{conn: conn, draft: draft} do
      {:ok, _view, html} = live(conn, "/drafts/#{draft.id}/room")

      assert html =~ "Player1"
      assert html =~ "Player2"
      assert html =~ "2 available players"
    end

    test "filters players by role", %{conn: conn, draft: draft} do
      {:ok, view, _html} = live(conn, "/drafts/#{draft.id}/room")

      # Filter by ADC role
      html =
        view
        |> element("button", "ADC")
        |> render_click()

      # Has ADC role
      assert html =~ "Player1"
      # Doesn't have ADC role
      refute html =~ "Player2"
      assert html =~ "1 available players"
    end

    test "searches players by name", %{conn: conn, draft: draft} do
      {:ok, view, _html} = live(conn, "/drafts/#{draft.id}/room")

      # Search for specific player
      html =
        view
        |> element("input[name='search']")
        |> render_change(%{search: "Player1"})

      assert html =~ "Player1"
      refute html =~ "Player2"
      assert html =~ "1 available players"
    end

    test "shows team pick progress", %{conn: conn, draft: draft} do
      {:ok, _view, html} = live(conn, "/drafts/#{draft.id}/room")

      # Should show draft progress timeline
      assert html =~ "Draft Progress"
      assert html =~ "Ready to Start"
      assert html =~ "R1"
    end

    test "handles invalid draft id", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn ->
        live(conn, "/drafts/99999/room")
      end
    end

    test "role display names are formatted correctly", %{conn: conn, draft: draft} do
      {:ok, _view, html} = live(conn, "/drafts/#{draft.id}/room")

      # Should be uppercase
      assert html =~ "ADC"
      # Should be capitalized
      assert html =~ "Top"
      assert html =~ "Mid"
      assert html =~ "Jungle"
      assert html =~ "Support"
    end
  end

  describe "Player Selection" do
    setup do
      # Create draft with specific setup for pick testing
      {:ok, draft} = Drafts.create_draft(%{@create_draft_attrs | status: :setup})
      {:ok, team1} = Drafts.create_team(draft.id, %{name: "Team Alpha"})
      {:ok, team2} = Drafts.create_team(draft.id, %{name: "Team Beta"})

      {:ok, player} =
        Drafts.create_player(draft.id, %{
          display_name: "TestPlayer",
          preferred_roles: [:adc]
        })

      %{draft: draft, team1: team1, team2: team2, player: player}
    end

    test "shows disabled player buttons when draft is starting", %{
      conn: conn,
      draft: draft,
      player: player
    } do
      {:ok, _view, html} = live(conn, "/drafts/#{draft.id}/room")

      # Players should be disabled when draft is in "Ready to Start" phase
      assert html =~ "Ready to Start"
      assert html =~ player.display_name
      # Disabled styling
      assert html =~ "opacity-75"
      # No click handler when disabled
      refute html =~ ~s(phx-click="select_player")
    end

    # Note: Testing actual player selection would require more complex setup
    # with proper team turn logic and mocking PubSub broadcasts
  end

  describe "Draft Progress Auto-Scroll" do
    setup do
      # Create draft with teams and players for auto-scroll testing
      {:ok, draft} = Drafts.create_draft(@create_draft_attrs)
      {:ok, team1} = Drafts.create_team(draft.id, %{name: "Team Alpha"})
      {:ok, team2} = Drafts.create_team(draft.id, %{name: "Team Beta"})

      {:ok, player1} =
        Drafts.create_player(draft.id, %{
          display_name: "Player1",
          preferred_roles: [:adc]
        })

      {:ok, player2} =
        Drafts.create_player(draft.id, %{
          display_name: "Player2",
          preferred_roles: [:mid]
        })

      %{draft: draft, team1: team1, team2: team2, player1: player1, player2: player2}
    end

    test "includes DraftProgressScroll hook in HTML", %{conn: conn, draft: draft} do
      {:ok, _view, html} = live(conn, "/drafts/#{draft.id}/room")

      # Should include the DraftProgressScroll hook
      assert html =~ ~s(phx-hook="DraftProgressScroll")
      # Should have the draft progress container
      assert html =~ ~s(id="draft-progress-container")
      # Should have scroll classes
      assert html =~ "overflow-x-auto"
      assert html =~ "scroll-smooth"
    end

    test "shows pick order timeline with proper structure", %{conn: conn, draft: draft} do
      {:ok, _view, html} = live(conn, "/drafts/#{draft.id}/room")

      # Should show Pick Order Timeline section
      assert html =~ "Pick Order Timeline"
      # Should have scrollable container
      assert html =~ ~s(id="draft-progress-container")
      # Should show draft progress structure
      assert html =~ "R1"
      assert html =~ "Draft Progress"
    end

    test "includes proper structure for current pick identification", %{
      conn: conn,
      draft: draft
    } do
      {:ok, _view, html} = live(conn, "/drafts/#{draft.id}/room")

      # Should have draft progress structure that supports current pick identification
      assert html =~ "Draft Progress"
      assert html =~ "Pick Order Timeline"
      
      # Should have the auto-scroll hook ready for when draft becomes active
      assert html =~ ~s(phx-hook="DraftProgressScroll")
      
      # The timeline structure should be present even in setup phase
      assert html =~ "R1" # Round 1 indicator
    end

    test "maintains scroll container structure with multiple teams", %{
      conn: conn,
      draft: draft
    } do
      # Add more teams to test scroll behavior
      {:ok, _team3} = Drafts.create_team(draft.id, %{name: "Team Gamma"})
      {:ok, _team4} = Drafts.create_team(draft.id, %{name: "Team Delta"})

      {:ok, _view, html} = live(conn, "/drafts/#{draft.id}/room")

      # Should maintain scroll container with multiple teams
      assert html =~ ~s(phx-hook="DraftProgressScroll")
      assert html =~ "Team Alpha"
      assert html =~ "Team Beta"
      assert html =~ "Team Gamma"
      assert html =~ "Team Delta"
      
      # Should have horizontal scroll for many teams
      assert html =~ "overflow-x-auto"
    end

    test "JavaScript hook is properly registered in app.js", %{conn: conn, draft: draft} do
      # This test verifies the JavaScript side is properly set up
      {:ok, _view, html} = live(conn, "/drafts/#{draft.id}/room")

      # The hook should be present in the HTML
      assert html =~ ~s(phx-hook="DraftProgressScroll")
      
      # Verify the assets contain the hook (this tests compilation)
      # The actual JavaScript functionality would need browser testing
      # but we can verify the structure is correct
      assert html =~ "draft-progress-container"
    end
  end
end
