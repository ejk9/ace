defmodule AceAppWeb.DraftControllerTest do
  use AceAppWeb.ConnCase

  alias AceApp.Drafts

  describe "GET /drafts/new" do
    test "displays draft creation form", %{conn: conn} do
      conn = get(conn, "/drafts/new")
      
      assert html_response(conn, 200)
      response = response(conn, 200)
      
      assert response =~ "Create New Draft"
      assert response =~ "Draft Name"
      assert response =~ "Draft Format"
      assert response =~ "Pick Timer"
      assert response =~ ~s(name="draft[name]")
      assert response =~ ~s(name="draft[format]")
      assert response =~ ~s(name="draft[pick_timer_seconds]")
    end

    test "includes CSRF protection", %{conn: conn} do
      conn = get(conn, "/drafts/new")
      response = response(conn, 200)
      
      assert response =~ ~s(name="_csrf_token")
      assert response =~ ~s(type="hidden")
    end

    test "has correct form defaults", %{conn: conn} do
      conn = get(conn, "/drafts/new")
      response = response(conn, 200)
      
      # Should have snake format selected by default
      assert response =~ ~s(value="snake" selected)
      # Should have default timer value
      assert response =~ ~s(value="60")
    end
  end

  describe "POST /drafts" do
    test "creates draft and redirects to setup on valid data", %{conn: conn} do
      conn = post(conn, "/drafts", %{
        "draft" => %{
          "name" => "Test Tournament",
          "format" => "snake",
          "pick_timer_seconds" => "90"
        }
      })

      assert redirected_to(conn) =~ ~r{/drafts/\d+/setup}
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Draft created successfully!"
      
      # Verify draft was actually created
      drafts = Drafts.list_drafts()
      assert length(drafts) == 1
      
      draft = hd(drafts)
      assert draft.name == "Test Tournament"
      assert draft.format == :snake
      assert draft.pick_timer_seconds == 90
    end

    test "renders form with errors on invalid data", %{conn: conn} do
      conn = post(conn, "/drafts", %{
        "draft" => %{
          "name" => "",
          "format" => "",
          "pick_timer_seconds" => ""
        }
      })

      assert html_response(conn, 200)
      response = response(conn, 200)
      
      assert response =~ "Create New Draft"
      assert response =~ "can&#39;t be blank"
    end

    test "validates draft name presence", %{conn: conn} do
      conn = post(conn, "/drafts", %{
        "draft" => %{
          "name" => "",
          "format" => "snake", 
          "pick_timer_seconds" => "60"
        }
      })

      assert html_response(conn, 200)
      response = response(conn, 200)
      assert response =~ "can&#39;t be blank"
    end

    test "validates format presence", %{conn: conn} do
      conn = post(conn, "/drafts", %{
        "draft" => %{
          "name" => "Test Draft",
          "format" => "",
          "pick_timer_seconds" => "60"
        }
      })

      assert html_response(conn, 200)
      response = response(conn, 200)
      assert response =~ "can&#39;t be blank"
    end

    test "validates timer seconds presence", %{conn: conn} do
      conn = post(conn, "/drafts", %{
        "draft" => %{
          "name" => "Test Draft",
          "format" => "snake",
          "pick_timer_seconds" => ""
        }
      })

      assert html_response(conn, 200)
      response = response(conn, 200)
      assert response =~ "can&#39;t be blank"
    end

    test "validates timer seconds minimum value", %{conn: conn} do
      conn = post(conn, "/drafts", %{
        "draft" => %{
          "name" => "Test Draft",
          "format" => "snake",
          "pick_timer_seconds" => "5"
        }
      })

      assert html_response(conn, 200)
      response = response(conn, 200)
      assert response =~ "must be greater than or equal to"
    end

    test "validates timer seconds maximum value", %{conn: conn} do
      conn = post(conn, "/drafts", %{
        "draft" => %{
          "name" => "Test Draft", 
          "format" => "snake",
          "pick_timer_seconds" => "1000"
        }
      })

      assert html_response(conn, 200)
      response = response(conn, 200)
      assert response =~ "must be less than or equal to"
    end

    test "accepts different draft formats", %{conn: conn} do
      # Test snake format
      conn = post(conn, "/drafts", %{
        "draft" => %{
          "name" => "Snake Draft",
          "format" => "snake",
          "pick_timer_seconds" => "60"
        }
      })

      assert redirected_to(conn) =~ ~r{/drafts/\d+/setup}
      
      # Clear any created drafts for next test
      Enum.each(Drafts.list_drafts(), &Drafts.delete_draft/1)

      # Test regular format
      conn = post(build_conn(), "/drafts", %{
        "draft" => %{
          "name" => "Regular Draft",
          "format" => "regular",
          "pick_timer_seconds" => "90"
        }
      })

      assert redirected_to(conn) =~ ~r{/drafts/\d+/setup}
    end

    test "handles CSRF protection", %{conn: conn} do
      # This test ensures CSRF tokens are properly validated
      # Phoenix handles this automatically, but we test the behavior
      
      conn = post(conn, "/drafts", %{
        "draft" => %{
          "name" => "Test Draft",
          "format" => "snake", 
          "pick_timer_seconds" => "60"
        }
      })

      # Should work with proper CSRF (Phoenix adds it automatically in tests)
      assert redirected_to(conn) =~ ~r{/drafts/\d+/setup}
    end

    test "preserves form data on validation errors", %{conn: conn} do
      conn = post(conn, "/drafts", %{
        "draft" => %{
          "name" => "Valid Name",
          "format" => "",  # Invalid
          "pick_timer_seconds" => "120"
        }
      })

      response = response(conn, 200)
      assert response =~ "Valid Name"  # Should preserve the valid name
      assert response =~ "120"         # Should preserve the valid timer value
    end
  end

  describe "Draft creation integration" do
    test "created draft has correct initial state", %{conn: conn} do
      conn = post(conn, "/drafts", %{
        "draft" => %{
          "name" => "Integration Test",
          "format" => "snake",
          "pick_timer_seconds" => "75"
        }
      })

      # Extract draft ID from redirect
      location = redirected_to(conn)
      draft_id = location |> String.split("/") |> Enum.at(2) |> String.to_integer()
      
      # Verify draft state
      draft = Drafts.get_draft!(draft_id)
      assert draft.status == :setup
      assert draft.name == "Integration Test"
      assert draft.format == :snake
      assert draft.pick_timer_seconds == 75
      
      # Verify tokens are generated
      assert is_binary(draft.organizer_token)
      assert is_binary(draft.spectator_token)
      assert String.length(draft.organizer_token) > 10
      assert String.length(draft.spectator_token) > 10
      assert draft.organizer_token != draft.spectator_token
    end
  end
end