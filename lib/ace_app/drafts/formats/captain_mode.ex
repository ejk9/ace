defmodule AceApp.Drafts.Formats.CaptainMode do
  @moduledoc """
  Captain mode draft implementation.

  In captain mode:
  - Each team has one designated captain who is excluded from picks
  - Only 4 rounds of picks (instead of 5)
  - Uses standard snake draft order (1-2-3, 3-2-1, 1-2-3, 3-2-1)
  - Captains are pre-assigned and cannot be picked
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
  def format_name, do: "Captain Mode"

  @impl true
  def picks_per_team, do: 4

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
