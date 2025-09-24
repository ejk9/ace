defmodule AceApp.Drafts.Formats.SnakeDraft do
  @moduledoc """
  Snake draft implementation.

  In snake draft format:
  - Teams pick in order (1, 2, 3, 4...)
  - Then reverse order (4, 3, 2, 1...)
  - Then forward again (1, 2, 3, 4...)
  - Pattern continues until all picks are made

  For 3 teams, 5 rounds:
  Round 1: Team1, Team2, Team3
  Round 2: Team3, Team2, Team1  
  Round 3: Team1, Team2, Team3
  Round 4: Team3, Team2, Team1
  Round 5: Team1, Team2, Team3
  """

  @behaviour AceApp.Drafts.DraftFormat

  alias AceApp.Repo

  @impl true
  def calculate_pick_order(teams, round) do
    sorted_teams = Enum.sort_by(teams, & &1.pick_order_position)

    if rem(round, 2) == 1 do
      # Odd rounds: forward order (1, 2, 3...)
      sorted_teams
    else
      # Even rounds: reverse order (...3, 2, 1)
      Enum.reverse(sorted_teams)
    end
  end

  @impl true
  def is_draft_complete?(draft) do
    draft = Repo.preload(draft, [:teams, :picks])
    total_teams = length(draft.teams)
    total_picks_made = length(draft.picks)
    expected_picks = total_teams * picks_per_team()

    total_picks_made >= expected_picks
  end

  @impl true
  def next_team(draft) do
    draft = Repo.preload(draft, [:teams, :picks])

    if is_draft_complete?(draft) do
      nil
    else
      # Calculate current round and position within round
      total_picks = length(draft.picks)
      num_teams = length(draft.teams)

      current_round = div(total_picks, num_teams) + 1
      position_in_round = rem(total_picks, num_teams)

      pick_order = calculate_pick_order(draft.teams, current_round)
      Enum.at(pick_order, position_in_round)
    end
  end

  @impl true
  def format_name, do: "Snake Draft"

  @impl true
  def picks_per_team, do: 5

  @doc """
  Get the next team to pick based on current pick number.
  This is a compatibility function for the Drafts context.
  """
  def get_next_team(draft, _pick_number) do
    case next_team(draft) do
      nil -> :draft_complete
      team -> {:ok, team}
    end
  end

  @doc """
  Get the current round number based on total picks made.
  """
  def current_round(total_picks, num_teams) when num_teams > 0 do
    div(total_picks, num_teams) + 1
  end

  def current_round(_, _), do: 1

  @doc """
  Get the pick number within the current round.
  """
  def position_in_round(total_picks, num_teams) when num_teams > 0 do
    rem(total_picks, num_teams)
  end

  def position_in_round(_, _), do: 0

  @doc """
  Generate the complete draft order for visualization.

  Returns a list of maps with round, pick_number, and team information.
  """
  def generate_full_draft_order(teams) do
    num_teams = length(teams)
    total_rounds = picks_per_team()

    for round <- 1..total_rounds,
        {team, position} <- Enum.with_index(calculate_pick_order(teams, round)) do
      pick_number = (round - 1) * num_teams + position + 1

      %{
        round: round,
        pick_number: pick_number,
        position_in_round: position + 1,
        team: team
      }
    end
  end
end
