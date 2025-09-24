defmodule AceApp.Drafts.DraftFormat do
  @moduledoc """
  Behavior defining the interface for draft formats.

  This allows us to implement different draft formats (snake, regular, auction)
  while maintaining a consistent API.
  """

  alias AceApp.Drafts.{Draft, Team}

  @doc """
  Calculate the pick order for teams in a given round.

  Returns a list of teams in the order they should pick.
  """
  @callback calculate_pick_order(teams :: [Team.t()], round :: integer()) :: [Team.t()]

  @doc """
  Determine if the draft is complete based on the current state.
  """
  @callback is_draft_complete?(draft :: Draft.t()) :: boolean()

  @doc """
  Get the next team that should pick in the draft.

  Returns nil if the draft is complete.
  """
  @callback next_team(draft :: Draft.t()) :: Team.t() | nil

  @doc """
  Get the human-readable name of this draft format.
  """
  @callback format_name() :: String.t()

  @doc """
  Get the total number of picks per team for this format.
  """
  @callback picks_per_team() :: integer()

  @doc """
  Get the implementation module for a given format atom.
  """
  def get_format_module(:snake), do: AceApp.Drafts.Formats.SnakeDraft
  def get_format_module(:regular), do: AceApp.Drafts.Formats.RegularDraft
  def get_format_module(:auction), do: AceApp.Drafts.Formats.AuctionDraft
  def get_format_module(_), do: {:error, :invalid_format}

  @doc """
  Get all available draft formats.
  """
  def available_formats do
    [
      %{id: :snake, name: "Snake Draft", description: "Serpentine order (1-2-3-3-2-1)"},
      %{id: :regular, name: "Regular Draft", description: "Fixed order each round (1-2-3-1-2-3)"},
      %{id: :auction, name: "Auction Draft", description: "Budget-based bidding system"}
    ]
  end
end
