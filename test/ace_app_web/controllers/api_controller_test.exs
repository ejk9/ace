defmodule AceAppWeb.ApiControllerTest do
  use AceAppWeb.ConnCase

  alias AceApp.Drafts

  setup do
    # Create a complete draft with teams, players, and picks for testing
    {:ok, draft} = Drafts.create_draft(%{
      name: "Test Tournament",
      format: :snake,
      pick_timer_seconds: 60
    })

    {:ok, team1} = Drafts.create_team(draft.id, %{name: "Blue Team", pick_order_position: 1})
    {:ok, team2} = Drafts.create_team(draft.id, %{name: "Red Team", pick_order_position: 2})

    {:ok, player1} = Drafts.create_player(draft.id, %{display_name: "Player One", preferred_roles: ["top"]})
    {:ok, player2} = Drafts.create_player(draft.id, %{display_name: "Player Two", preferred_roles: ["jungle"]})
    {:ok, player3} = Drafts.create_player(draft.id, %{display_name: "Player Three", preferred_roles: ["mid"]})

    # Start the draft and make some picks
    {:ok, draft} = Drafts.start_draft(draft.id)
    {:ok, _pick1} = Drafts.make_pick(draft.id, team1.id, player1.id, %{}, false)
    {:ok, _pick2} = Drafts.make_pick(draft.id, team2.id, player2.id, %{}, false)

    %{
      draft: Drafts.get_draft_with_associations!(draft.id),
      team1: team1,
      team2: team2,
      players: [player1, player2, player3]
    }
  end

  describe "GET /api/drafts/:id/status.csv" do
    test "returns CSV with pick-by-pick data", %{conn: conn, draft: draft} do
      conn = get(conn, "/api/drafts/#{draft.id}/status.csv")
      
      assert response(conn, 200)
      assert get_resp_header(conn, "content-type") == ["text/csv; charset=utf-8"]
      assert get_resp_header(conn, "content-disposition") == ["attachment; filename=\"draft_#{draft.id}_status.csv\""]
      
      csv_content = response(conn, 200)
      lines = String.split(csv_content, "\n")
      
      # Should have header + 2 picks + empty line at end
      assert length(lines) >= 3
      
      # Check header
      header = hd(lines)
      assert header == "Pick Order,Round,Team,Player,Picked At"
      
      # Check first pick
      [pick_order, round, team, player, _picked_at] = 
        lines |> Enum.at(1) |> String.split(",")
      
      assert pick_order == "1"
      assert round == "1"
      assert team == "Blue Team"
      assert player == "Player One"
    end

    test "handles draft with no picks", %{conn: conn} do
      # Create a draft with no picks
      {:ok, empty_draft} = Drafts.create_draft(%{
        name: "Empty Draft",
        format: :snake,
        pick_timer_seconds: 60
      })

      conn = get(conn, "/api/drafts/#{empty_draft.id}/status.csv")
      
      assert response(conn, 200)
      csv_content = response(conn, 200)
      
      # Should only have header
      lines = String.split(csv_content, "\n")
      assert length(lines) == 2  # header + empty line
      assert hd(lines) == "Pick Order,Round,Team,Player,Picked At"
    end

    test "returns 404 for non-existent draft", %{conn: conn} do
      conn = get(conn, "/api/drafts/99999/status.csv")
      assert response(conn, 404)
    end

    test "CSV format is properly escaped", %{conn: conn} do
      # Create draft with special characters in names
      {:ok, special_draft} = Drafts.create_draft(%{
        name: "Draft with \"quotes\" and, commas",
        format: :snake,
        pick_timer_seconds: 60
      })

      {:ok, special_team} = Drafts.create_team(special_draft.id, %{
        name: "Team with \"quotes\"", 
        pick_order_position: 1
      })

      {:ok, special_player} = Drafts.create_player(special_draft.id, %{
        display_name: "Player, with commas",
        preferred_roles: ["top"]
      })

      {:ok, _} = Drafts.start_draft(special_draft.id)
      {:ok, _} = Drafts.make_pick(special_draft.id, special_team.id, special_player.id, %{}, false)

      conn = get(conn, "/api/drafts/#{special_draft.id}/status.csv")
      
      csv_content = response(conn, 200)
      
      # Should properly escape quotes and commas
      assert csv_content =~ "\"Team with \"\"quotes\"\"\""
      assert csv_content =~ "\"Player, with commas\""
    end
  end

  describe "GET /api/drafts/:id/teams.csv" do
    test "returns CSV with team information", %{conn: conn, draft: draft} do
      conn = get(conn, "/api/drafts/#{draft.id}/teams.csv")
      
      assert response(conn, 200)
      assert get_resp_header(conn, "content-type") == ["text/csv; charset=utf-8"]
      assert get_resp_header(conn, "content-disposition") == ["attachment; filename=\"draft_#{draft.id}_teams.csv\""]
      
      csv_content = response(conn, 200)
      lines = String.split(csv_content, "\n")
      
      # Should have header + draft info + teams
      assert length(lines) >= 4
      
      # Check header
      header = hd(lines)
      assert header == "Type,Name,Pick Order,Players,Status"
      
      # Check draft info line
      draft_line = Enum.at(lines, 1)
      assert draft_line =~ "Draft"
      assert draft_line =~ draft.name
      assert draft_line =~ "Active"
      
      # Check team lines
      blue_team_line = Enum.find(lines, &String.contains?(&1, "Blue Team"))
      assert blue_team_line
      assert blue_team_line =~ "Team,Blue Team,1"
      
      red_team_line = Enum.find(lines, &String.contains?(&1, "Red Team"))
      assert red_team_line
      assert red_team_line =~ "Team,Red Team,2"
    end

    test "shows correct player counts", %{conn: conn, draft: draft} do
      conn = get(conn, "/api/drafts/#{draft.id}/teams.csv")
      
      csv_content = response(conn, 200)
      
      # Blue team should show 1 player (has 1 pick)
      assert csv_content =~ "Blue Team,1,1"
      # Red team should show 1 player (has 1 pick)  
      assert csv_content =~ "Red Team,2,1"
    end

    test "handles different draft statuses", %{conn: conn, draft: draft} do
      # Test setup status
      {:ok, setup_draft} = Drafts.create_draft(%{
        name: "Setup Draft",
        format: :snake,
        pick_timer_seconds: 60
      })

      conn = get(conn, "/api/drafts/#{setup_draft.id}/teams.csv")
      csv_content = response(conn, 200)
      assert csv_content =~ "Setup"

      # Test completed status
      completed_draft = draft
      Ecto.Changeset.change(completed_draft, status: :completed)
      |> AceApp.Repo.update!()

      conn = get(build_conn(), "/api/drafts/#{completed_draft.id}/teams.csv")
      csv_content = response(conn, 200)
      assert csv_content =~ "Completed"
    end

    test "returns 404 for non-existent draft", %{conn: conn} do
      conn = get(conn, "/api/drafts/99999/teams.csv")
      assert response(conn, 404)
    end
  end

  describe "CSV export edge cases" do
    test "handles drafts with empty team names", %{conn: conn} do
      {:ok, edge_draft} = Drafts.create_draft(%{
        name: "Edge Case Draft",
        format: :snake,
        pick_timer_seconds: 60
      })

      {:ok, _team} = Drafts.create_team(edge_draft.id, %{
        name: "",  # Empty name
        pick_order_position: 1
      })

      conn = get(conn, "/api/drafts/#{edge_draft.id}/teams.csv")
      assert response(conn, 200)
    end

    test "handles very long team and player names", %{conn: conn} do
      long_name = String.duplicate("A", 255)
      
      {:ok, long_draft} = Drafts.create_draft(%{
        name: "Long Names Draft",
        format: :snake,
        pick_timer_seconds: 60
      })

      {:ok, long_team} = Drafts.create_team(long_draft.id, %{
        name: long_name,
        pick_order_position: 1
      })

      {:ok, long_player} = Drafts.create_player(long_draft.id, %{
        display_name: long_name,
        preferred_roles: ["top"]
      })

      {:ok, _} = Drafts.start_draft(long_draft.id)
      {:ok, _} = Drafts.make_pick(long_draft.id, long_team.id, long_player.id, %{}, false)

      conn = get(conn, "/api/drafts/#{long_draft.id}/status.csv")
      assert response(conn, 200)
      
      csv_content = response(conn, 200)
      assert String.contains?(csv_content, long_name)
    end
  end
end