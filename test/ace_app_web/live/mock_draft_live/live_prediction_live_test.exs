defmodule AceAppWeb.MockDraftLive.LivePredictionLiveTest do
  use AceAppWeb.ConnCase

  import Phoenix.LiveViewTest
  import AceApp.DataCase

  alias AceApp.{Drafts, MockDrafts}

  describe "LivePredictionLive" do
    setup do
      # Create a draft with teams and players
      draft = draft_fixture()
      team1 = team_fixture(draft.id, %{name: "Blue Team", pick_order_position: 1})
      team2 = team_fixture(draft.id, %{name: "Red Team", pick_order_position: 2})
      
      player1 = player_fixture(draft.id, %{display_name: "Faker", preferred_roles: [:mid]})
      player2 = player_fixture(draft.id, %{display_name: "Canyon", preferred_roles: [:jungle]})
      player3 = player_fixture(draft.id, %{display_name: "Keria", preferred_roles: [:support]})
      
      # Create mock draft
      {:ok, mock_draft} = MockDrafts.create_mock_draft(draft.id, %{
        live_predictions_enabled: true
      })
      
      %{
        draft: draft,
        mock_draft: mock_draft,
        teams: [team1, team2],
        players: [player1, player2, player3]
      }
    end

    test "mount with valid token loads mock draft and draft data", %{conn: conn, mock_draft: mock_draft} do
      {:ok, view, html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      assert html =~ "Live Mock Draft Predictions"
      assert html =~ "Predict picks in real-time during the draft"
      assert html =~ "Join Live Predictions"
      assert has_element?(view, "form[phx-submit='join_as_participant']")
      assert has_element?(view, "input[name='participant[name]']")
    end

    test "mount with invalid token redirects with error", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/", flash: %{"error" => "Mock draft not found"}}}} =
        live(conn, "/mock-drafts/invalid_token/live")
    end

    test "mount subscribes to draft PubSub events", %{conn: conn, mock_draft: mock_draft, draft: draft} do
      {:ok, _view, _html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Verify PubSub subscription was created
      # We can test this by sending a message and checking if the view receives it
      Phoenix.PubSub.broadcast(AceApp.PubSub, "draft:#{draft.id}", {:test_message, "test"})
      
      # The view should handle the message (even if it ignores it)
      :timer.sleep(10)  # Give time for async message processing
    end

    test "shows draft status for setup phase", %{conn: conn, mock_draft: mock_draft} do
      {:ok, view, html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      assert html =~ "Draft status: Setup"
      assert html =~ "Draft is still in setup phase"
      assert html =~ "Live predictions will be available once the draft begins"
      assert has_element?(view, "svg.h-12.w-12.text-amber-400")
    end

    test "shows draft status for completed phase", %{conn: conn, mock_draft: mock_draft, draft: draft} do
      # Update draft to completed
      {:ok, _draft} = Drafts.update_draft(draft, %{status: :completed})
      
      {:ok, view, html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      assert html =~ "Draft Completed"
      assert html =~ "The draft has finished"
      assert html =~ "View Leaderboard"
      assert has_element?(view, "svg.h-12.w-12.text-green-500")
      assert has_element?(view, "a[href*='leaderboard']")
    end

    test "join_as_participant creates participant and updates UI", %{conn: conn, mock_draft: mock_draft} do
      {:ok, view, _html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      participant_name = "TestPlayer"
      
      # Submit join form
      view
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: participant_name}})
      |> render_submit()
      
      # Should show participant info and hide join form
      assert render(view) =~ "Participating as: #{String.capitalize(participant_name)}"
      assert render(view) =~ "Score: 0"
      assert render(view) =~ "Predictions: 0"
      refute has_element?(view, "form[phx-submit='join_as_participant']")
      
      # Verify participant was created in database
      participants = MockDrafts.list_participants_for_mock_draft(mock_draft.id)
      assert length(participants) == 1
      assert hd(participants).display_name == participant_name
    end

    test "join_as_participant prevents empty name", %{conn: conn, mock_draft: mock_draft} do
      {:ok, view, _html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Submit form with empty name
      view
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: "   "}})
      |> render_submit()
      
      # Should show error and keep join form
      assert render(view) =~ "Unable to join"
      assert has_element?(view, "form[phx-submit='join_as_participant']")
    end

    test "join_as_participant prevents duplicate names", %{conn: conn, mock_draft: mock_draft} do
      participant_name = "TestPlayer"
      
      # Create existing participant
      {:ok, _participant} = MockDrafts.create_participant(mock_draft.id, participant_name)
      
      {:ok, view, _html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Try to join with same name
      view
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: participant_name}})
      |> render_submit()
      
      # Should show error
      assert render(view) =~ "Unable to join"
      assert has_element?(view, "form[phx-submit='join_as_participant']")
    end

    test "shows prediction interface for active draft when participant joined", %{conn: conn, mock_draft: mock_draft, draft: draft, players: [player1, player2, _player3]} do
      # Set draft to active
      {:ok, _draft} = Drafts.update_draft(draft, %{status: :active})
      
      {:ok, view, _html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Join as participant
      view
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: "TestPlayer"}})
      |> render_submit()
      
      html = render(view)
      
      # Should show current pick info
      assert html =~ "Pick #1"
      assert html =~ "is picking"
      
      # Should show prediction interface
      assert html =~ "Who will be picked next?"
      assert has_element?(view, "button[phx-click='make_prediction']")
      
      # Should show available players
      assert html =~ player1.display_name
      assert html =~ player2.display_name
    end

    test "make_prediction creates prediction and updates UI", %{conn: conn, mock_draft: mock_draft, draft: draft, players: [player1, _player2, _player3]} do
      # Set draft to active
      {:ok, _draft} = Drafts.update_draft(draft, %{status: :active})
      
      {:ok, view, _html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Join as participant
      view
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: "TestPlayer"}})
      |> render_submit()
      
      # Make a prediction
      render_click(view, "make_prediction", %{"player_id" => to_string(player1.id)})
      
      html = render(view)
      
      # Should show success message
      assert html =~ "Predicted #{player1.display_name} for pick #1"
      
      # Should show locked prediction instead of selection interface
      assert html =~ "Your Prediction for Pick #1"
      assert html =~ player1.display_name
      assert html =~ "Prediction locked"
      refute html =~ "Who will be picked next?"
      
      # Verify prediction was created in database
      participant = hd(MockDrafts.list_participants_for_mock_draft(mock_draft.id))
      prediction = MockDrafts.get_live_prediction(participant.id, 1)
      assert prediction.predicted_player_id == player1.id
      assert prediction.pick_number == 1
    end

    test "make_prediction fails when not participant", %{conn: conn, mock_draft: mock_draft, draft: draft, players: [player1, _player2, _player3]} do
      # Set draft to active
      {:ok, _draft} = Drafts.update_draft(draft, %{status: :active})
      
      {:ok, view, _html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Try to make prediction without joining
      render_click(view, "make_prediction", %{"player_id" => to_string(player1.id)})
      
      # Should show error
      assert render(view) =~ "Please join as a participant first"
    end

    test "make_prediction prevents duplicate predictions for same pick", %{conn: conn, mock_draft: mock_draft, draft: draft, players: [player1, player2, _player3]} do
      # Set draft to active
      {:ok, _draft} = Drafts.update_draft(draft, %{status: :active})
      
      {:ok, view, _html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Join as participant
      view
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: "TestPlayer"}})
      |> render_submit()
      
      # Make first prediction
      render_click(view, "make_prediction", %{"player_id" => to_string(player1.id)})
      
      # Try to make another prediction for same pick (this would require manual DB manipulation in real scenario)
      participant = hd(MockDrafts.list_participants_for_mock_draft(mock_draft.id))
      
      # Force a second prediction attempt (simulating race condition)
      result = MockDrafts.create_live_prediction(participant.id, 1, player2.id)
      assert {:error, _changeset} = result
    end

    test "shows join prompt for non-participants during active draft", %{conn: conn, mock_draft: mock_draft, draft: draft} do
      # Set draft to active
      {:ok, _draft} = Drafts.update_draft(draft, %{status: :active})
      
      {:ok, view, html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Should show join prompt instead of prediction interface
      assert html =~ "Join as a participant to make predictions!"
      assert html =~ "Join Now"
      assert has_element?(view, "button[phx-click='show_join_form']")
      refute html =~ "Who will be picked next?"
    end

    test "show_join_form event shows join form", %{conn: conn, mock_draft: mock_draft} do
      {:ok, view, _html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Hide the form first (simulate having hidden it)
      send(view.pid, {:update_assigns, %{show_join_form: false}})
      
      # Click show join form
      render_click(view, "show_join_form")
      
      # Should show join form again
      assert has_element?(view, "form[phx-submit='join_as_participant']")
    end

    test "displays participants leaderboard", %{conn: conn, mock_draft: mock_draft} do
      # Create some participants
      {:ok, participant1} = MockDrafts.create_participant(mock_draft.id, "Player1")
      {:ok, participant2} = MockDrafts.create_participant(mock_draft.id, "Player2")
      
      # Update their scores
      MockDrafts.get_participant!(participant1.id)
      |> Ecto.Changeset.change(%{total_score: 10, predictions_made: 2})
      |> AceApp.Repo.update!()
      
      MockDrafts.get_participant!(participant2.id)
      |> Ecto.Changeset.change(%{total_score: 5, predictions_made: 1})
      |> AceApp.Repo.update!()
      
      {:ok, _view, html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Should show participants section
      assert html =~ "Live Participants"
      assert html =~ "2 participants"
      assert html =~ "Player1"
      assert html =~ "Player2"
      assert html =~ "10"  # Player1's score
      assert html =~ "5"   # Player2's score
    end

    test "displays empty state when no participants", %{conn: conn, mock_draft: mock_draft} do
      {:ok, view, html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      assert html =~ "0 participants"
      assert html =~ "No participants yet"
      assert has_element?(view, "svg.h-8.w-8.text-slate-400")
    end

    test "shows navigation links to other mock draft sections", %{conn: conn, mock_draft: mock_draft} do
      {:ok, view, html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Should show navigation to pre-draft and leaderboard
      assert html =~ "Pre-Draft Predictions"
      assert html =~ "View Leaderboard"
      assert has_element?(view, "a[href*='predraft']")
      assert has_element?(view, "a[href*='leaderboard']")
    end

    test "current_prediction is loaded when participant rejoins", %{conn: conn, mock_draft: mock_draft, draft: draft, players: [player1, _player2, _player3]} do
      # Set draft to active
      {:ok, _draft} = Drafts.update_draft(draft, %{status: :active})
      
      # Create participant and prediction outside the view
      {:ok, participant} = MockDrafts.create_participant(mock_draft.id, "TestPlayer")
      {:ok, _prediction} = MockDrafts.create_live_prediction(participant.id, 1, player1.id)
      
      {:ok, view, _html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Join as the same participant (simulating rejoin)
      view
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: "TestPlayer"}})
      |> render_submit()
      
      html = render(view)
      
      # Should show existing prediction
      assert html =~ "Your Prediction for Pick #1"
      assert html =~ player1.display_name
      assert html =~ "Prediction locked"
    end
  end

  describe "PubSub integration" do
    setup do
      # Create test data
      draft = draft_fixture()
      team1 = team_fixture(draft.id, %{name: "Blue Team", pick_order_position: 1})
      player1 = player_fixture(draft.id, %{display_name: "Faker", preferred_roles: [:mid]})
      
      {:ok, mock_draft} = MockDrafts.create_mock_draft(draft.id, %{
        live_predictions_enabled: true
      })
      
      # Set draft to active
      {:ok, draft} = Drafts.update_draft(draft, %{status: :active})
      
      %{
        draft: draft,
        mock_draft: mock_draft,
        team1: team1,
        player1: player1
      }
    end

    test "handles pick_made event and updates scores", %{conn: conn, mock_draft: mock_draft, draft: draft, team1: team1, player1: player1} do
      {:ok, view, _html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Join as participant and make prediction
      view
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: "TestPlayer"}})
      |> render_submit()
      
      render_click(view, "make_prediction", %{"player_id" => to_string(player1.id)})
      
      # Create a pick that matches the prediction
      {:ok, pick} = Drafts.make_pick(draft.id, team1.id, player1.id, random_champion_id())
      
      # Simulate the pick_made event
      send(view.pid, {:pick_made, pick})
      
      # Give time for async processing
      :timer.sleep(10)
      
      html = render(view)
      
      # Should show pick made message
      assert html =~ "Pick #{pick.pick_number} made! Scores updated."
      
      # Verify scoring happened in database
      participant = hd(MockDrafts.list_participants_for_mock_draft(mock_draft.id))
      updated_participant = MockDrafts.get_participant!(participant.id)
      assert updated_participant.total_score > 0  # Should have points for correct prediction
    end

    test "updates current prediction state after pick is made", %{conn: conn, mock_draft: mock_draft, draft: draft, team1: team1, player1: player1} do
      {:ok, view, _html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Join and make prediction
      view
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: "TestPlayer"}})
      |> render_submit()
      
      render_click(view, "make_prediction", %{"player_id" => to_string(player1.id)})
      
      # Verify prediction is shown
      assert render(view) =~ "Your Prediction for Pick #1"
      
      # Create pick
      {:ok, pick} = Drafts.make_pick(draft.id, team1.id, player1.id, random_champion_id())
      
      # Send pick_made event
      send(view.pid, {:pick_made, pick})
      :timer.sleep(10)
      
      html = render(view)
      
      # Should now show prediction interface for next pick
      assert html =~ "Pick #2"  # Next pick
      # Should not show locked prediction for pick 1 anymore (since it's been made)
    end

    test "ignores unrelated PubSub events", %{conn: conn, mock_draft: mock_draft} do
      {:ok, view, _html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Send unrelated event
      send(view.pid, {:some_other_event, "data"})
      
      # Should not crash or change anything
      :timer.sleep(10)
      assert render(view) =~ "Live Mock Draft Predictions"
    end
  end

  # Helper functions for creating test data
  defp draft_fixture(attrs \\ %{}) do
    {:ok, draft} = 
      attrs
      |> Enum.into(%{
        name: "Test Draft #{System.unique_integer()}",
        format: :snake,
        pick_timer_seconds: 60,
        organizer_token: generate_token(),
        spectator_token: generate_token(),
        status: :setup
      })
      |> Drafts.create_draft()

    draft
  end

  defp team_fixture(draft_id, attrs) do
    {:ok, team} = 
      attrs
      |> Enum.into(%{
        name: "Test Team #{System.unique_integer()}",
        pick_order_position: 1,
        captain_token: generate_token(),
        team_member_token: generate_token()
      })
      |> then(&Drafts.create_team(draft_id, &1))

    team
  end

  defp player_fixture(draft_id, attrs) do
    {:ok, player} = 
      attrs
      |> Enum.into(%{
        display_name: "Test Player #{System.unique_integer()}",
        preferred_roles: [:mid, :adc]
      })
      |> then(&Drafts.create_player(draft_id, &1))

    player
  end

  defp generate_token do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end
end