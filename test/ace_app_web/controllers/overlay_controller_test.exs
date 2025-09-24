defmodule AceAppWeb.OverlayControllerTest do
  use AceAppWeb.ConnCase

  alias AceApp.Drafts

  setup do
    # Create a draft with teams and players for testing overlays
    {:ok, draft} = Drafts.create_draft(%{
      name: "Overlay Test Tournament",
      format: :snake,
      pick_timer_seconds: 90
    })

    {:ok, team1} = Drafts.create_team(draft.id, %{name: "Alpha Team", pick_order_position: 1})
    {:ok, team2} = Drafts.create_team(draft.id, %{name: "Beta Team", pick_order_position: 2})

    {:ok, player1} = Drafts.create_player(draft.id, %{display_name: "TopLaner", preferred_roles: ["top"]})
    {:ok, player2} = Drafts.create_player(draft.id, %{display_name: "Jungler", preferred_roles: ["jungle"]})
    {:ok, player3} = Drafts.create_player(draft.id, %{display_name: "MidLaner", preferred_roles: ["mid"]})

    %{
      draft: Drafts.get_draft_with_associations!(draft.id),
      teams: [team1, team2],
      players: [player1, player2, player3]
    }
  end

  describe "GET /overlay/:id/draft" do
    test "returns HTML draft overlay", %{conn: conn, draft: draft} do
      conn = get(conn, "/overlay/#{draft.id}/draft")
      
      assert html_response(conn, 200)
      response_body = response(conn, 200)
      
      # Should contain HTML structure
      assert response_body =~ "<html"
      assert response_body =~ "<head>"
      assert response_body =~ "<body>"
      
      # Should contain draft information
      assert response_body =~ draft.name
      assert response_body =~ "Alpha Team"
      assert response_body =~ "Beta Team"
      
      # Should include CSS and JavaScript
      assert response_body =~ "<style>"
      assert response_body =~ "<script>"
      
      # Should have meta tags for OBS
      assert response_body =~ "viewport"
      assert response_body =~ "charset=utf-8"
    end

    test "supports logo_only query parameter", %{conn: conn, draft: draft} do
      conn = get(conn, "/overlay/#{draft.id}/draft?logo_only=true")
      
      response_body = response(conn, 200)
      assert html_response(conn, 200)
      
      # Should still contain basic structure
      assert response_body =~ draft.name
      assert response_body =~ "Alpha Team"
      assert response_body =~ "Beta Team"
    end

    test "handles draft with picks", %{conn: conn, draft: draft, teams: [team1, _team2], players: [player1, _player2, _player3]} do
      # Start draft and make a pick
      {:ok, draft} = Drafts.start_draft(draft.id)
      {:ok, _pick} = Drafts.make_pick(draft.id, team1.id, player1.id, %{}, false)
      
      conn = get(conn, "/overlay/#{draft.id}/draft")
      
      response_body = response(conn, 200)
      assert html_response(conn, 200)
      
      # Should show the pick
      assert response_body =~ "TopLaner"
    end

    test "returns 404 for non-existent draft", %{conn: conn} do
      conn = get(conn, "/overlay/99999/draft")
      assert response(conn, 404)
    end
  end

  describe "GET /overlay/:id/current-pick" do
    test "returns current pick overlay", %{conn: conn, draft: draft} do
      conn = get(conn, "/overlay/#{draft.id}/current-pick")
      
      assert html_response(conn, 200)
      response_body = response(conn, 200)
      
      # Should contain HTML structure
      assert response_body =~ "<html"
      assert response_body =~ "current-pick"
      
      # Should contain draft information
      assert response_body =~ draft.name
    end

    test "shows active team when draft is in progress", %{conn: conn, draft: draft, teams: [_team1, _team2]} do
      # Start the draft
      {:ok, _draft} = Drafts.start_draft(draft.id)
      
      conn = get(conn, "/overlay/#{draft.id}/current-pick")
      
      response_body = response(conn, 200)
      assert html_response(conn, 200)
      
      # Should show current team (first team in snake draft)
      assert response_body =~ "Alpha Team"
    end

    test "handles draft not started", %{conn: conn, draft: draft} do
      conn = get(conn, "/overlay/#{draft.id}/current-pick")
      
      response_body = response(conn, 200)
      assert html_response(conn, 200)
      
      # Should handle gracefully
      assert response_body =~ "Waiting"
    end

    test "returns 404 for non-existent draft", %{conn: conn} do
      conn = get(conn, "/overlay/99999/current-pick")
      assert response(conn, 404)
    end
  end

  describe "GET /overlay/:id/roster" do
    test "returns team roster overlay", %{conn: conn, draft: draft} do
      conn = get(conn, "/overlay/#{draft.id}/roster")
      
      assert html_response(conn, 200)
      response_body = response(conn, 200)
      
      # Should contain HTML structure
      assert response_body =~ "<html"
      assert response_body =~ "roster"
      
      # Should show all teams
      assert response_body =~ "Alpha Team"
      assert response_body =~ "Beta Team"
    end

    test "shows team rosters with picks", %{conn: conn, draft: draft, teams: [team1, team2], players: [player1, player2, _player3]} do
      # Start draft and make picks
      {:ok, draft} = Drafts.start_draft(draft.id)
      {:ok, _pick1} = Drafts.make_pick(draft.id, team1.id, player1.id, %{}, false)
      {:ok, _pick2} = Drafts.make_pick(draft.id, team2.id, player2.id, %{}, false)
      
      conn = get(conn, "/overlay/#{draft.id}/roster")
      
      response_body = response(conn, 200)
      assert html_response(conn, 200)
      
      # Should show picked players
      assert response_body =~ "TopLaner"
      assert response_body =~ "Jungler"
    end

    test "handles empty rosters", %{conn: conn, draft: draft} do
      conn = get(conn, "/overlay/#{draft.id}/roster")
      
      response_body = response(conn, 200)
      assert html_response(conn, 200)
      
      # Should still show team structure
      assert response_body =~ "Alpha Team"
      assert response_body =~ "Beta Team"
    end

    test "returns 404 for non-existent draft", %{conn: conn} do
      conn = get(conn, "/overlay/99999/roster")
      assert response(conn, 404)
    end
  end

  describe "GET /overlay/:id/available" do
    test "returns available players overlay", %{conn: conn, draft: draft} do
      conn = get(conn, "/overlay/#{draft.id}/available")
      
      assert html_response(conn, 200)
      response_body = response(conn, 200)
      
      # Should contain HTML structure
      assert response_body =~ "<html"
      assert response_body =~ "available"
      
      # Should show all players initially
      assert response_body =~ "TopLaner"
      assert response_body =~ "Jungler" 
      assert response_body =~ "MidLaner"
    end

    test "updates available players after picks", %{conn: conn, draft: draft, teams: [team1, _team2], players: [player1, _player2, _player3]} do
      # Start draft and make a pick
      {:ok, draft} = Drafts.start_draft(draft.id)
      {:ok, _pick} = Drafts.make_pick(draft.id, team1.id, player1.id, %{}, false)
      
      conn = get(conn, "/overlay/#{draft.id}/available")
      
      response_body = response(conn, 200)
      assert html_response(conn, 200)
      
      # Should not show picked player
      refute response_body =~ "TopLaner"
      # Should still show available players
      assert response_body =~ "Jungler"
      assert response_body =~ "MidLaner"
    end

    test "groups players by role", %{conn: conn, draft: draft} do
      conn = get(conn, "/overlay/#{draft.id}/available")
      
      response_body = response(conn, 200)
      assert html_response(conn, 200)
      
      # Should have role sections
      assert response_body =~ "Top"
      assert response_body =~ "Jungle"
      assert response_body =~ "Mid"
    end

    test "returns 404 for non-existent draft", %{conn: conn} do
      conn = get(conn, "/overlay/99999/available")
      assert response(conn, 404)
    end
  end

  describe "Overlay integration" do
    test "all overlays have consistent structure", %{conn: _conn, draft: draft} do
      overlays = [
        "/overlay/#{draft.id}/draft",
        "/overlay/#{draft.id}/current-pick", 
        "/overlay/#{draft.id}/roster",
        "/overlay/#{draft.id}/available"
      ]

      for overlay_path <- overlays do
        conn = get(build_conn(), overlay_path)
        response_body = response(conn, 200)
        
        # All should have valid HTML
        assert response_body =~ "<!DOCTYPE html>"
        assert response_body =~ "<html"
        assert response_body =~ "</html>"
        
        # All should have meta tags for OBS
        assert response_body =~ "charset=utf-8"
        assert response_body =~ "viewport"
        
        # All should have CSS
        assert response_body =~ "<style>"
        
        # All should have JavaScript for real-time updates
        assert response_body =~ "<script>"
      end
    end

    test "overlays are mobile responsive", %{conn: conn, draft: draft} do
      conn = get(conn, "/overlay/#{draft.id}/draft")
      response_body = response(conn, 200)
      
      # Should have responsive viewport
      assert response_body =~ "width=device-width"
      assert response_body =~ "initial-scale=1"
    end

    test "overlays have proper caching headers", %{conn: conn, draft: draft} do
      conn = get(conn, "/overlay/#{draft.id}/draft")
      
      # Should have appropriate cache headers for real-time data
      cache_control = get_resp_header(conn, "cache-control")
      assert cache_control != []
    end
  end
end