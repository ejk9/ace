defmodule AceApp.Drafts do
  @moduledoc """
  The Drafts context.
  """

  require Logger
  import Ecto.Query, warn: false
  alias AceApp.Repo

  alias AceApp.Drafts.{
    Draft,
    Team,
    Player,
    PlayerAccount,
    Pick,
    PickQueue,
    SpectatorControls,
    DraftEvent,
    ChatMessage,
    DraftSnapshot,
    DraftAuditLog,
    TimerManager
  }

  ## Drafts

  @doc """
  Returns the list of drafts.

  ## Examples

      iex> list_drafts()
      [%Draft{}, ...]

  """
  def list_drafts do
    Draft
    |> preload(:teams)
    |> Repo.all()
  end

  @doc """
  Returns the list of drafts for a specific user.

  ## Examples

      iex> list_user_drafts(user_id)
      [%Draft{}, ...]

  """
  def list_user_drafts(user_id) do
    Draft
    |> where([d], d.user_id == ^user_id)
    |> preload(:teams)
    |> Repo.all()
  end

  @doc """
  Returns the list of public drafts only.

  ## Examples

      iex> list_public_drafts()
      [%Draft{}, ...]

  """
  def list_public_drafts do
    Draft
    |> where([d], d.visibility == :public)
    |> preload(:teams)
    |> order_by([d], desc: d.updated_at)
    |> Repo.all()
  end

  @doc """
  Returns drafts accessible to a specific authenticated user.
  This includes their own drafts (public + private) plus other users' public drafts.

  ## Examples

      iex> list_accessible_drafts_for_user(user_id)
      [%Draft{}, ...]

  """
  def list_accessible_drafts_for_user(user_id) do
    Draft
    |> where([d], d.user_id == ^user_id or d.visibility == :public)
    |> preload(:teams)
    |> order_by([d], desc: d.updated_at)
    |> Repo.all()
  end

  @doc """
  Gets a single draft.

  Raises `Ecto.NoResultsError` if the Draft does not exist.

  ## Examples

      iex> get_draft!(123)
      %Draft{}

      iex> get_draft!(456)
      ** (Ecto.NoResultsError)

  """
  def get_draft!(id), do: Repo.get!(Draft, id)

  @doc """
  Gets a draft with preloaded associations for the draft room
  """
  def get_draft_with_associations!(id) do
    Repo.get!(Draft, id)
    |> Repo.preload([
      :teams,
      picks: [:player, :team],
      players: [:champion]
    ])
  end

  @doc """
  Gets a draft by organizer token.
  """
  def get_draft_by_organizer_token(token) do
    Repo.get_by(Draft, organizer_token: token)
  end

  @doc """
  Gets a draft by spectator token.
  """
  def get_draft_by_spectator_token(token) do
    Repo.get_by(Draft, spectator_token: token)
  end

  @doc """
  Creates a draft.

  ## Examples

      iex> create_draft(%{field: value})
      {:ok, %Draft{}}

      iex> create_draft(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_draft(attrs \\ %{}) do
    result = %Draft{}
    |> Draft.changeset(attrs)
    |> Repo.insert()
    
    case result do
      {:ok, draft} ->
        :telemetry.execute([:ace_app, :drafts, :created], %{count: 1}, %{draft_id: draft.id})
        {:ok, draft}
      error ->
        error
    end
  end

  @doc """
  Updates a draft.

  ## Examples

      iex> update_draft(draft, %{field: new_value})
      {:ok, %Draft{}}

      iex> update_draft(draft, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_draft(%Draft{} = draft, attrs) do
    draft
    |> Draft.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates a draft's timer state fields.
  Used by DraftTimer GenServer to persist timer state.
  """
  def update_draft_timer_state(draft_id, timer_attrs) do
    draft = get_draft!(draft_id)
    update_draft(draft, timer_attrs)
  end

  @doc """
  Gets the current timer state for a draft.
  """
  def get_timer_state(draft_id) do
    case AceApp.Drafts.TimerManager.get_timer_state(draft_id) do
      {:ok, timer_state} -> {:ok, timer_state}
      {:error, _reason} -> {:error, :timer_not_found}
    end
  end

  @doc """
  Deletes a draft.

  ## Examples

      iex> delete_draft(draft)
      {:ok, %Draft{}}

      iex> delete_draft(draft)
      {:error, %Ecto.Changeset{}}

  """
  def delete_draft(%Draft{} = draft) do
    Repo.delete(draft)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking draft changes.

  ## Examples

      iex> change_draft(draft)
      %Ecto.Changeset{data: %Draft{}}

  """
  def change_draft(%Draft{} = draft, attrs \\ %{}) do
    Draft.changeset(draft, attrs)
  end

  @doc """
  Starts a draft if all teams are ready.
  """
  def start_draft(draft_id) do
    draft = get_draft!(draft_id)

    case {draft.status, all_teams_ready?(draft_id)} do
      {:setup, true} ->
        case update_draft(draft, %{status: :active}) do
          {:ok, updated_draft} ->
            log_draft_event(draft_id, "draft_started", %{})
            
            # Create initial snapshot at start of draft (pick 0)
            create_draft_snapshot(draft_id, 0, nil, "Draft Start")
            
            # Log audit event for draft start
            log_audit_event(draft_id, "draft_started", %{
              format: updated_draft.format,
              pick_timer_seconds: updated_draft.pick_timer_seconds,
              teams_count: length(updated_draft.teams || [])
            }, "system", "system")
            
            # Telemetry for draft started
            :telemetry.execute([:ace_app, :drafts, :started], %{count: 1}, %{
              draft_id: draft_id,
              format: updated_draft.format,
              teams_count: length(updated_draft.teams || [])
            })
            
            # Start timer process for this draft
            TimerManager.start_timer_for_draft(draft_id)
            
            # Check if the first team has a queued pick to execute, or start timer
            process_team_turn_with_timer(draft_id)
            
            {:ok, updated_draft}

          error ->
            error
        end

      {:setup, false} ->
        {:error, :teams_not_ready}

      {status, _} ->
        {:error, {:invalid_status, status}}
    end
  end

  @doc """
  Starts a preview draft with automated picks.
  This will start the draft normally, but mark it for automated picking.
  """
  def start_preview_draft(draft_id) do
    draft = get_draft_with_associations!(draft_id)
    
    IO.puts("=== START PREVIEW DRAFT DEBUG ===")
    IO.puts("Draft status: #{draft.status}")
    IO.puts("Teams count: #{length(draft.teams)}")
    
    case draft.status do
      :setup ->
        # Start the draft without team ready requirement for preview mode
        case start_draft_for_preview(draft_id) do
          {:ok, updated_draft} ->
            # Add a chat message indicating preview mode
            send_system_message(draft_id, "Preview draft started - picks will be made automatically")
            # Start automated picking process
            spawn(fn -> automated_preview_picks(draft_id) end)
            {:ok, updated_draft}
          error ->
            error
        end
      :active ->
        IO.puts("Draft already active, continuing with preview picks...")
        # If draft is already active, just start making preview picks
        send_system_message(draft_id, "Preview mode activated - continuing with automatic picks")
        {:ok, draft}
      _ ->
        IO.puts("Draft in unsupported status: #{draft.status}")
        {:error, :draft_not_ready}
    end
  end

  # Automated preview picking process that runs independently
  defp automated_preview_picks(draft_id) do
    # Wait 2 seconds before making the first automated pick
    Process.sleep(2000)
    make_automated_pick(draft_id)
  end

  defp make_automated_pick(draft_id) do
    draft = get_draft_with_associations!(draft_id)
    
    if draft.status == :active do
      current_team = Enum.find(draft.teams, &(&1.id == draft.current_turn_team_id))
      available_players = list_available_players(draft_id)
      
      if current_team && length(available_players) > 0 do
        # Pick a random player
        random_player = Enum.random(available_players)
        
        # Make the pick
        case make_pick(draft_id, current_team.id, random_player.id, nil, false) do
          {:ok, _pick} ->
            # Add a chat message for the preview pick
            send_system_message(draft_id, "Preview: #{current_team.name} picked #{random_player.display_name}")
            
            # Check if draft is still active after this pick
            updated_draft = get_draft_with_associations!(draft_id)
            if updated_draft.status == :active do
              # Schedule next pick in 2 seconds
              Process.sleep(2000)
              make_automated_pick(draft_id)
            else
              # Draft is complete
              send_system_message(draft_id, "Preview draft completed!")
            end
          {:error, reason} ->
            IO.puts("Automated pick failed: #{inspect(reason)}")
            # Try again in 1 second if there was an error
            Process.sleep(1000)
            make_automated_pick(draft_id)
        end
      else
        # No available picks - draft might be complete
        send_system_message(draft_id, "Preview draft completed - no more picks available!")
      end
    end
  end

  # Starts a draft for preview mode, bypassing team ready requirements.
  defp start_draft_for_preview(draft_id) do
    draft = get_draft_with_associations!(draft_id)

    case draft.status do
      :setup ->
        teams_count = length(draft.teams || [])
        
        case update_draft(draft, %{status: :active}) do
          {:ok, updated_draft} ->
            log_draft_event(draft_id, "preview_draft_started", %{})
            
            # Create initial snapshot at start of preview draft (pick 0)
            create_draft_snapshot(draft_id, 0, nil, "Preview Draft Start")
            
            # Log audit event for preview draft start
            log_audit_event(draft_id, "preview_draft_started", %{
              format: updated_draft.format,
              pick_timer_seconds: updated_draft.pick_timer_seconds,
              teams_count: teams_count
            }, "system", "preview_mode")
            
            # Telemetry for preview draft started
            :telemetry.execute([:ace_app, :drafts, :preview_started], %{count: 1}, %{
              draft_id: draft_id,
              format: updated_draft.format,
              teams_count: teams_count
            })
            
            # Start timer process for this draft (preview mode)
            TimerManager.start_timer_for_draft(draft_id)
            
            # Check if the first team has a queued pick to execute, or start timer
            process_team_turn_with_timer(draft_id)
            
            {:ok, updated_draft}

          error ->
            error
        end

      status ->
        {:error, {:invalid_status, status}}
    end
  end

  @doc """
  Stops/pauses a draft.
  """
  def stop_draft(draft_id) do
    draft = get_draft!(draft_id)

    case draft.status do
      :active ->
        case update_draft(draft, %{status: :paused}) do
          {:ok, updated_draft} ->
            # Pause the timer when draft is paused
            TimerManager.pause_timer(draft_id)
            log_draft_event(draft_id, "draft_paused", %{})
            {:ok, updated_draft}

          error ->
            error
        end

      status ->
        {:error, {:invalid_status, status}}
    end
  end

  @doc """
  Resumes a paused draft.
  """
  def resume_draft(draft_id) do
    draft = get_draft!(draft_id)

    case draft.status do
      :paused ->
        case update_draft(draft, %{status: :active}) do
          {:ok, updated_draft} ->
            # Resume the timer when draft is resumed
            TimerManager.resume_timer(draft_id)
            log_draft_event(draft_id, "draft_resumed", %{})
            # Check if the current team has a queued pick to execute
            process_team_turn_with_timer(draft_id)
            {:ok, updated_draft}

          error ->
            error
        end

      status ->
        {:error, {:invalid_status, status}}
    end
  end

  @doc """
  Resets a draft back to setup state.
  """
  def reset_draft(draft_id) do
    draft = get_draft!(draft_id)

    Repo.transaction(fn ->
      # Stop and cleanup timer
      TimerManager.stop_timer(draft_id)
      TimerManager.stop_timer_for_draft(draft_id)
      
      # Delete all picks
      from(p in Pick, where: p.draft_id == ^draft_id) |> Repo.delete_all()

      # Reset all teams to not ready
      from(t in Team, where: t.draft_id == ^draft_id)
      |> Repo.update_all(set: [is_ready: false])

      # Reset draft status
      case update_draft(draft, %{status: :setup}) do
        {:ok, updated_draft} ->
          log_draft_event(draft_id, "draft_reset", %{})
          updated_draft

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  ## Teams

  @doc """
  Returns the list of teams for a draft.
  """
  def list_teams(draft_id) do
    from(t in Team,
      where: t.draft_id == ^draft_id,
      order_by: t.pick_order_position
    )
    |> Repo.all()
  end

  @doc """
  Gets a single team.
  """
  def get_team!(id), do: Repo.get!(Team, id)

  @doc """
  Gets a team by captain token.
  """
  def get_team_by_captain_token(token) do
    Repo.get_by(Team, captain_token: token)
  end

  def get_team_by_team_member_token(token) do
    Repo.get_by(Team, team_member_token: token)
  end

  @doc """
  Creates a team for a draft.
  """
  def create_team(draft_id, attrs \\ %{}) do
    # Get the next pick order position
    next_position = get_next_team_position(draft_id)

    attrs =
      attrs
      |> Enum.map(fn {k, v} -> {to_string(k), v} end)
      |> Enum.into(%{})
      |> Map.put("draft_id", draft_id)
      |> Map.put_new("pick_order_position", next_position)

    result = %Team{}
    |> Team.changeset(attrs)
    |> Repo.insert()
    
    case result do
      {:ok, team} ->
        :telemetry.execute([:ace_app, :teams, :created], %{count: 1}, %{
          draft_id: draft_id,
          team_id: team.id
        })
        {:ok, team}
      error ->
        error
    end
  end

  @doc """
  Updates a team.
  """
  def update_team(%Team{} = team, attrs) do
    team
    |> Team.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a team.
  """
  def delete_team(%Team{} = team) do
    Repo.delete(team)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking team changes.
  """
  def change_team(%Team{} = team, attrs \\ %{}) do
    Team.changeset(team, attrs)
  end

  @doc """
  Toggles a team's ready state.
  """
  def toggle_team_ready(team_id) do
    team = get_team!(team_id)
    update_team(team, %{is_ready: !team.is_ready})
  end

  @doc """
  Sets a team's ready state.
  """
  def set_team_ready(team_id, ready_state) when is_boolean(ready_state) do
    team = get_team!(team_id)
    update_team(team, %{is_ready: ready_state})
  end

  @doc """
  Checks if all teams in a draft are ready.
  """
  def all_teams_ready?(draft_id) do
    ready_states =
      from(t in Team, where: t.draft_id == ^draft_id, select: t.is_ready)
      |> Repo.all()

    case ready_states do
      # No teams means not ready
      [] -> false
      states -> Enum.all?(states)
    end
  end

  @doc """
  Gets the ready status for all teams in a draft.
  """
  def get_teams_ready_status(draft_id) do
    from(t in Team,
      where: t.draft_id == ^draft_id,
      select: %{id: t.id, name: t.name, is_ready: t.is_ready},
      order_by: t.pick_order_position
    )
    |> Repo.all()
  end

  @doc """
  Reorder teams in a draft.
  """
  def reorder_teams(draft_id, team_ids) when is_list(team_ids) do
    Repo.transaction(fn ->
      # First, set all positions to negative values to avoid conflicts
      team_ids
      |> Enum.with_index(1)
      |> Enum.each(fn {team_id, position} ->
        from(t in Team, where: t.id == ^team_id and t.draft_id == ^draft_id)
        |> Repo.update_all(set: [pick_order_position: -position])
      end)

      # Then, set all positions to positive values
      team_ids
      |> Enum.with_index(1)
      |> Enum.each(fn {team_id, position} ->
        from(t in Team, where: t.id == ^team_id and t.draft_id == ^draft_id)
        |> Repo.update_all(set: [pick_order_position: position])
      end)
    end)
  end

  @doc """
  Get teams with their current picks for a draft.
  """
  def get_teams_with_picks(draft_id) do
    from(t in Team,
      where: t.draft_id == ^draft_id,
      left_join: p in Pick,
      on: p.team_id == t.id,
      left_join: pl in Player,
      on: p.player_id == pl.id,
      order_by: [t.pick_order_position, p.pick_number],
      preload: [picks: {p, player: pl}]
    )
    |> Repo.all()
  end

  ## Players

  @doc """
  Returns the list of players for a draft.
  """
  def list_players(draft_id) do
    from(p in Player,
      where: p.draft_id == ^draft_id,
      order_by: p.display_name,
      preload: [:player_accounts]
    )
    |> Repo.all()
  end

  @doc """
  Returns available (unpicked) players for a draft.
  """
  def list_available_players(draft_id) do
    picked_player_ids =
      from(pk in Pick,
        where: pk.draft_id == ^draft_id,
        select: pk.player_id
      )

    from(p in Player,
      where: p.draft_id == ^draft_id and p.id not in subquery(picked_player_ids),
      order_by: p.display_name,
      preload: [:player_accounts]
    )
    |> Repo.all()
  end

  @doc """
  Filter available players by role.
  """
  def list_available_players_by_role(draft_id, role) do
    list_available_players(draft_id)
    |> Enum.filter(fn player ->
      role in player.preferred_roles
    end)
  end

  @doc """
  Search players by name.
  """
  def search_players(draft_id, search_term) do
    search_pattern = "%#{String.downcase(search_term)}%"

    from(p in Player,
      where:
        p.draft_id == ^draft_id and fragment("LOWER(?) LIKE ?", p.display_name, ^search_pattern),
      order_by: p.display_name,
      preload: [:player_accounts]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single player.
  """
  def get_player!(id) do
    Repo.get!(Player, id)
    |> Repo.preload([:player_accounts, :draft])
  end

  @doc """
  Creates a player for a draft.
  """
  def create_player(draft_id, attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.map(fn {k, v} -> {to_string(k), v} end)
      |> Enum.into(%{})
      |> Map.put("draft_id", draft_id)

    result = %Player{}
    |> Player.changeset(attrs)
    |> Repo.insert()
    
    case result do
      {:ok, player} ->
        # Automatically assign a random champion if none specified
        updated_player = if is_nil(player.champion_id) do
          case assign_random_champion_to_player(player) do
            {:ok, player_with_champion} -> player_with_champion
            {:error, _} -> player  # Keep original player if champion assignment fails
          end
        else
          player
        end
        
        :telemetry.execute([:ace_app, :players, :created], %{count: 1}, %{
          draft_id: draft_id,
          player_id: updated_player.id
        })
        {:ok, updated_player}
      error ->
        error
    end
  end

  # Assigns a random champion and skin to a single player.
  # Helper function for automatic champion assignment.
  defp assign_random_champion_to_player(player) do
    available_champions = AceApp.LoL.list_enabled_champions()
    
    if length(available_champions) > 0 do
      random_champion = Enum.random(available_champions)
      
      # Also pick a random skin for consistency
      available_skins = AceApp.LoL.list_champion_skins(random_champion.id)
      random_skin = if length(available_skins) > 0, do: Enum.random(available_skins), else: nil
      
      assign_champion_to_player(player.id, random_champion.id, random_skin && random_skin.skin_id)
    else
      {:error, :no_champions_available}
    end
  end

  @doc """
  Updates a player.
  """
  def update_player(%Player{} = player, attrs) do
    player
    |> Player.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a player.
  """
  def delete_player(%Player{} = player) do
    Repo.delete(player)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking player changes.
  """
  def change_player(%Player{} = player, attrs \\ %{}) do
    Player.changeset(player, attrs)
  end

  @doc """
  Import players from a list of attributes.
  Useful for CSV import functionality.
  """
  def import_players(draft_id, players_attrs) when is_list(players_attrs) do
    Repo.transaction(fn ->
      Enum.map(players_attrs, fn attrs ->
        case create_player(draft_id, attrs) do
          {:ok, player} -> player
          {:error, changeset} -> Repo.rollback({:player_error, attrs, changeset})
        end
      end)
    end)
  end

  @doc """
  Get player statistics for a draft.
  """
  def get_player_stats(draft_id) do
    %{
      total_players: get_player_count(draft_id),
      players_by_role: get_players_by_role_count(draft_id),
      available_players: get_available_player_count(draft_id)
    }
  end

  defp get_player_count(draft_id) do
    from(p in Player, where: p.draft_id == ^draft_id, select: count(p.id))
    |> Repo.one()
  end

  defp get_available_player_count(draft_id) do
    picked_player_ids = from(pk in Pick, where: pk.draft_id == ^draft_id, select: pk.player_id)

    from(p in Player,
      where: p.draft_id == ^draft_id and p.id not in subquery(picked_player_ids),
      select: count(p.id)
    )
    |> Repo.one()
  end

  defp get_players_by_role_count(draft_id) do
    # This is a bit complex with arrays, but we can use a raw query or process in Elixir
    players = list_players(draft_id)

    AceApp.LoL.roles()
    |> Enum.map(fn role ->
      count =
        Enum.count(players, fn player ->
          role in player.preferred_roles
        end)

      {role, count}
    end)
    |> Enum.into(%{})
  end

  # Private helper functions

  defp get_next_team_position(draft_id) do
    case from(t in Team, where: t.draft_id == ^draft_id, select: max(t.pick_order_position))
         |> Repo.one() do
      nil -> 1
      max_position -> max_position + 1
    end
  end

  defp calculate_round_number(draft_id, pick_number) do
    team_count = from(t in Team, where: t.draft_id == ^draft_id, select: count()) |> Repo.one()
    div(pick_number - 1, team_count) + 1
  end

  ## Player Account management

  @doc """
  Returns the list of player_accounts for a given player.
  """
  def list_player_accounts(%Player{} = player) do
    player
    |> Repo.preload(:player_accounts)
    |> Map.get(:player_accounts)
  end

  @doc """
  Gets a single player_account.
  """
  def get_player_account!(id), do: Repo.get!(PlayerAccount, id)

  @doc """
  Creates a player_account.
  """
  def create_player_account(%Player{} = player, attrs \\ %{}) do
    %PlayerAccount{}
    |> PlayerAccount.changeset(Map.put(attrs, "player_id", player.id))
    |> Repo.insert()
  end



  @doc """
  Updates a player_account.
  """
  def update_player_account(%PlayerAccount{} = player_account, attrs) do
    player_account
    |> PlayerAccount.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a player_account.
  """
  def delete_player_account(%PlayerAccount{} = player_account) do
    Repo.delete(player_account)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking player_account changes.
  """
  def change_player_account(%PlayerAccount{} = player_account, attrs \\ %{}) do
    PlayerAccount.changeset(player_account, attrs)
  end

  @doc """
  Gets the primary account for a player (highest ranked account).
  """
  def get_primary_player_account(%Player{} = player) do
    player
    |> list_player_accounts()
    |> Enum.sort_by(
      fn account ->
        tier_order = [
          :iron,
          :bronze,
          :silver,
          :gold,
          :platinum,
          :emerald,
          :diamond,
          :master,
          :grandmaster,
          :challenger
        ]

        division_order = [:iv, :iii, :ii, :i]

        tier_index = Enum.find_index(tier_order, &(&1 == account.rank_tier)) || 0

        division_index =
          if account.rank_division,
            do: Enum.find_index(division_order, &(&1 == account.rank_division)) || 0,
            else: 0

        {tier_index, division_index}
      end,
      :desc
    )
    |> List.first()
  end

  ## Pick management

  @doc """
  Returns the list of picks for a draft.
  """
  def list_picks(draft_id) do
    from(p in Pick,
      where: p.draft_id == ^draft_id,
      order_by: p.pick_number,
      preload: [:player, :team]
    )
    |> Repo.all()
  end

  @doc """
  Returns the list of picks for a specific team.
  """
  def get_team_picks(draft_id, team_id) do
    from(p in Pick,
      where: p.draft_id == ^draft_id and p.team_id == ^team_id,
      order_by: [asc: p.pick_number]
    )
    |> Repo.all()
    |> Repo.preload([:player, :team])
  end

  @doc """
  Returns the count of picks for a draft.
  """
  def count_picks(draft_id) do
    from(p in Pick,
      where: p.draft_id == ^draft_id,
      select: count()
    )
    |> Repo.one()
  end

  @doc """
  Preloads pick associations (team and player).
  """
  def preload_pick_associations(pick) do
    Repo.preload(pick, [:team, :player, :champion])
  end

  @doc """
  Auto-assign random champions to players who don't have one assigned.
  This ensures every player has a champion for splash art display.
  """
  def auto_assign_missing_champions(draft_id) do
    # Get all players without assigned champions
    players_without_champions = 
      from(p in Player, 
        where: p.draft_id == ^draft_id and is_nil(p.champion_id),
        preload: [:champion]
      )
      |> Repo.all()

    # Get all available champions
    available_champions = AceApp.LoL.list_enabled_champions()

    # Assign random champions to players without assignments
    Enum.each(players_without_champions, fn player ->
      random_champion = Enum.random(available_champions)
      
      player
      |> Player.changeset(%{champion_id: random_champion.id})
      |> Repo.update()
    end)

    {:ok, length(players_without_champions)}
  end

  @doc """
  Assign a specific champion to a player.
  """
  def assign_champion_to_player(player_id, champion_id, preferred_skin_id \\ nil) do
    player = get_player!(player_id)
    
    attrs = %{champion_id: champion_id}
    attrs = if preferred_skin_id, do: Map.put(attrs, :preferred_skin_id, preferred_skin_id), else: attrs
    
    player
    |> Player.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Assigns random champions to players who don't have champions assigned.
  """
  def assign_random_champions_to_players(draft_id) do
    # Get all players without champions
    players_without_champions = 
      from(p in Player, 
        where: p.draft_id == ^draft_id and is_nil(p.champion_id),
        preload: [:champion]
      )
      |> Repo.all()

    if length(players_without_champions) == 0 do
      {:ok, 0}
    else
      # Get all available champions
      available_champions = AceApp.LoL.list_enabled_champions()
      
      if length(available_champions) == 0 do
        {:error, :no_champions_available}
      else
        Repo.transaction(fn ->
          Enum.each(players_without_champions, fn player ->
            # Pick a random champion
            random_champion = Enum.random(available_champions)
            
            # Also pick a random skin for consistency
            available_skins = AceApp.LoL.list_champion_skins(random_champion.id)
            random_skin = if length(available_skins) > 0, do: Enum.random(available_skins), else: nil
            
            # Assign the champion with specific skin
            case assign_champion_to_player(player.id, random_champion.id, random_skin && random_skin.skin_id) do
              {:ok, _updated_player} -> :ok
              {:error, changeset} -> Repo.rollback({:champion_assignment_failed, player.id, changeset})
            end
          end)
          
          length(players_without_champions)
        end)
      end
    end
  end

  @doc """
  Assigns random skins to players who have champions but no preferred skin.
  """
  def assign_random_skins_to_players(draft_id) do
    # Get all players with champions but no preferred skin
    players_without_skins = 
      from(p in Player, 
        where: p.draft_id == ^draft_id and not is_nil(p.champion_id) and is_nil(p.preferred_skin_id),
        preload: [:champion]
      )
      |> Repo.all()

    if length(players_without_skins) == 0 do
      {:ok, 0}
    else
      Repo.transaction(fn ->
        Enum.each(players_without_skins, fn player ->
          # Get available skins for the player's champion
          available_skins = AceApp.LoL.list_champion_skins(player.champion.id)
          
          if length(available_skins) > 0 do
            random_skin = Enum.random(available_skins)
            
            case assign_champion_to_player(player.id, player.champion_id, random_skin.skin_id) do
              {:ok, _updated_player} -> :ok
              {:error, changeset} -> Repo.rollback({:skin_assignment_failed, player.id, changeset})
            end
          end
        end)
        
        length(players_without_skins)
      end)
    end
  end

  @doc """
  Backfills random champions for all drafts that have players without champions.
  Useful for updating existing drafts.
  """
  def backfill_random_champions_for_all_drafts() do
    # Get all drafts that have players without champions
    draft_ids_needing_champions = 
      from(d in Draft,
        join: p in Player, on: p.draft_id == d.id,
        where: is_nil(p.champion_id),
        select: d.id,
        distinct: true
      )
      |> Repo.all()

    results = Enum.map(draft_ids_needing_champions, fn draft_id ->
      case assign_random_champions_to_players(draft_id) do
        {:ok, count} -> {:ok, draft_id, count}
        {:error, reason} -> {:error, draft_id, reason}
      end
    end)

    successful_drafts = Enum.filter(results, fn 
      {:ok, _, _} -> true
      _ -> false
    end)

    failed_drafts = Enum.filter(results, fn 
      {:error, _, _} -> true
      _ -> false
    end)

    total_players_assigned = successful_drafts 
    |> Enum.map(fn {:ok, _, count} -> count end)
    |> Enum.sum()

    %{
      drafts_updated: length(successful_drafts),
      drafts_failed: length(failed_drafts),
      total_players_assigned: total_players_assigned,
      results: results
    }
  end

  @doc """
  Gets a single pick.
  """
  def get_pick!(id), do: Repo.get!(Pick, id) |> Repo.preload([:player, :team, :draft])

  @doc """
  Makes a pick for a team in a draft.
  """
  def make_pick(draft_id, team_id, player_id, champion_id \\ nil, is_queued \\ false) do
    with {:ok, draft} <- get_draft_if_active(draft_id),
         {:ok, _team} <- validate_team_turn(draft, team_id),
         {:ok, _player} <- validate_player_available(draft_id, player_id) do
      pick_number = get_next_pick_number(draft_id)
      round_number = calculate_round_number(draft_id, pick_number)
      final_champion_id = champion_id || get_next_available_champion()

      %Pick{}
      |> Pick.changeset(%{
        draft_id: draft_id,
        team_id: team_id,
        player_id: player_id,
        champion_id: final_champion_id,
        pick_number: pick_number,
        round_number: round_number,
        picked_at: DateTime.utc_now()
      })
      |> Repo.insert()
      |> case do
        {:ok, pick} ->
          log_draft_event(draft_id, "pick_made", %{
            team_id: team_id,
            player_id: player_id,
            pick_number: pick_number
          })

          # Send system chat message about the pick
          pick_with_associations = pick |> Repo.preload([:player, :team])

          message =
            if is_queued do
              "#{pick_with_associations.team.name}'s queued pick executed: #{pick_with_associations.player.display_name}"
            else
              "#{pick_with_associations.team.name} selected #{pick_with_associations.player.display_name}"
            end

          send_chat_message(
            draft_id,
            "system",
            "Draft System",
            message
          )

          # Clear this player from all other teams' queues (queue conflict resolution)
          clear_player_from_other_queues(draft_id, team_id, player_id)

          # Create snapshot after successful pick for rollback capability
          try do
            create_draft_snapshot(draft_id, pick_number)
          rescue
            error ->
              Logger.warning("Failed to create draft snapshot: #{inspect(error)}")
          end

          # Log audit event for the pick
          log_audit_event(draft_id, "pick_made", %{
            team_id: team_id,
            player_id: player_id,
            champion_id: champion_id,
            pick_number: pick_number,
            round_number: round_number,
            was_queued: is_queued
          }, "system", "system")

          # Telemetry for pick made
          :telemetry.execute([:ace_app, :picks, :made], %{count: 1}, %{
            draft_id: draft_id,
            team_id: team_id,
            pick_number: pick_number,
            round_number: round_number,
            was_queued: is_queued
          })

          # Broadcast pick made event to all connected clients
          Phoenix.PubSub.broadcast(
            AceApp.PubSub,
            "draft:#{draft_id}",
            {:pick_made, pick}
          )

          # Send Discord notification for pick via queue
          draft = get_draft!(draft_id)
          player = get_player!(pick.player_id)
          IO.puts("=== DISCORD QUEUE DEBUG ===")
          IO.puts("Drafts: Enqueueing Discord notification for pick #{pick.id}, player #{player.display_name}")
          IO.puts("Draft webhook_url: #{inspect(draft.discord_webhook_url)}")
          IO.puts("Draft webhook_validated: #{draft.discord_webhook_validated}")
          IO.puts("Draft notifications_enabled: #{draft.discord_notifications_enabled}")
          Logger.info("Drafts: Enqueueing Discord notification for pick #{pick.id}, player #{player.display_name}")
          AceApp.DiscordQueue.enqueue_pick_notification(draft, pick, player)

          # Stop current timer and check if the next team has a queued pick
          # Only continue processing if this wasn't a queued pick execution (to avoid infinite loops)
          TimerManager.stop_timer(draft_id)
          unless is_queued do
            process_team_turn_with_timer(draft_id)
          end

          maybe_complete_draft(draft)
          {:ok, pick}

        error ->
          error
      end
    end
  end

  @doc """
  Undoes the last pick in a draft (admin function).
  """
  def undo_last_pick(draft_id) do
    case get_last_pick(draft_id) do
      nil ->
        {:error, :no_picks_to_undo}

      pick ->
        Repo.transaction(fn ->
          Repo.delete!(pick)

          log_draft_event(draft_id, "pick_undone", %{
            team_id: pick.team_id,
            player_id: pick.player_id,
            pick_number: pick.pick_number
          })
        end)
    end
  end

  @doc """
  Gets the current pick number for a draft.
  """
  def get_current_pick_number(draft_id) do
    get_next_pick_number(draft_id) - 1
  end

  @doc """
  Gets the team that should pick next.
  """
  def get_next_team_to_pick(%Draft{} = draft) do
    draft = draft |> Repo.preload(:teams)
    pick_number = get_next_pick_number(draft.id)

    case AceApp.Drafts.Formats.SnakeDraft.get_next_team(draft, pick_number) do
      {:ok, team} -> team
      :draft_complete -> nil
    end
  end

  # Private helper functions for pick management

  defp get_draft_if_active(draft_id) do
    case get_draft_with_associations!(draft_id) do
      %Draft{status: :active} = draft -> {:ok, draft}
      %Draft{status: status} -> {:error, {:draft_not_active, status}}
    end
  end

  defp validate_team_turn(draft, team_id) do
    case get_next_team_to_pick(draft) do
      %Team{id: ^team_id} = team -> {:ok, team}
      %Team{id: other_id} -> {:error, {:not_team_turn, other_id}}
      nil -> {:error, :draft_complete}
    end
  end

  defp validate_player_available(draft_id, player_id) do
    case player_id in get_picked_player_ids(draft_id) do
      false ->
        case get_player!(player_id) do
          %Player{draft_id: ^draft_id} = player -> {:ok, player}
          _ -> {:error, :player_not_in_draft}
        end

      true ->
        {:error, :player_already_picked}
    end
  end

  defp validate_player_not_already_queued(draft_id, team_id, player_id) do
    case from(pq in PickQueue,
           where: pq.draft_id == ^draft_id and 
                  pq.team_id == ^team_id and 
                  pq.player_id == ^player_id and 
                  pq.status == "queued")
         |> Repo.one() do
      nil -> {:ok, :not_queued}
      _queued_pick -> {:error, :player_already_queued}
    end
  end

  defp get_next_available_champion do
    # Get a random enabled champion for splash art display
    case AceApp.LoL.list_enabled_champions() do
      [] -> 
        # Fallback to any champion if no enabled champions
        case AceApp.LoL.list_champions() do
          [] -> nil
          champions -> Enum.random(champions).id
        end
      enabled_champions ->
        Enum.random(enabled_champions).id
    end
  end

  defp validate_team_exists(draft, team_id) do
    case Enum.find(draft.teams, &(&1.id == team_id)) do
      nil -> {:error, :team_not_found}
      team -> {:ok, team}
    end
  end

  defp validate_team_token(team, token) do
    case token do
      t when t == team.captain_token or t == team.team_member_token -> {:ok, :valid}
      _ -> {:error, :invalid_token}
    end
  end

  defp get_team_by_id(team_id) do
    case Repo.get(Team, team_id) do
      nil -> {:error, :team_not_found}
      team -> {:ok, team}
    end
  end

  defp get_picked_player_ids(draft_id) do
    from(p in Pick, where: p.draft_id == ^draft_id, select: p.player_id)
    |> Repo.all()
  end



  defp get_next_pick_number(draft_id) do
    case from(p in Pick, where: p.draft_id == ^draft_id, select: max(p.pick_number))
         |> Repo.one() do
      nil -> 1
      max_pick -> max_pick + 1
    end
  end

  defp get_last_pick(draft_id) do
    from(p in Pick,
      where: p.draft_id == ^draft_id,
      order_by: [desc: p.pick_number],
      limit: 1,
      preload: [:player, :team]
    )
    |> Repo.one()
  end

  defp maybe_complete_draft(%Draft{} = draft) do
    total_teams = from(t in Team, where: t.draft_id == ^draft.id, select: count()) |> Repo.one()
    total_picks = from(p in Pick, where: p.draft_id == ^draft.id, select: count()) |> Repo.one()

    # Assuming 5 picks per team for a standard LoL draft
    if total_picks >= total_teams * 5 do
      case update_draft(draft, %{status: :completed}) do
        {:ok, completed_draft} ->
          log_draft_event(draft.id, "draft_completed", %{})
          
          # Telemetry for draft completed
          :telemetry.execute([:ace_app, :drafts, :completed], %{count: 1}, %{
            draft_id: draft.id,
            total_picks: total_picks,
            total_teams: total_teams,
            format: draft.format
          })
          
          {:ok, completed_draft}
        error ->
          error
      end
    end
  end

  ## Draft Event logging

  @doc """
  Returns the list of draft events for a draft.
  """
  def list_draft_events(draft_id) do
    from(e in DraftEvent,
      where: e.draft_id == ^draft_id,
      order_by: [asc: e.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Logs a draft event for audit trail purposes.
  """
  def log_draft_event(draft_id, event_type, event_data \\ %{}) do
    %DraftEvent{}
    |> DraftEvent.changeset(%{
      draft_id: draft_id,
      event_type: event_type,
      event_data: event_data
    })
    |> Repo.insert()
  end

  @doc """
  Gets draft events by type.
  """
  def get_draft_events_by_type(draft_id, event_type) do
    from(e in DraftEvent,
      where: e.draft_id == ^draft_id and e.event_type == ^event_type,
      order_by: [asc: e.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Gets draft events in a time range.
  """
  def get_draft_events_in_range(draft_id, start_time, end_time) do
    from(e in DraftEvent,
      where:
        e.draft_id == ^draft_id and
          e.inserted_at >= ^start_time and
          e.inserted_at <= ^end_time,
      order_by: [asc: e.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Reconstructs the draft timeline from events.
  Useful for showing a complete audit trail.
  """
  def get_draft_timeline(draft_id) do
    events = list_draft_events(draft_id)

    events
    |> Enum.map(fn event ->
      %{
        timestamp: event.inserted_at,
        event_type: event.event_type,
        description: format_event_description(event),
        event_data: event.event_data
      }
    end)
  end

  @doc """
  Gets event statistics for a draft.
  """
  def get_draft_event_stats(draft_id) do
    events = list_draft_events(draft_id)

    %{
      total_events: length(events),
      events_by_type: Enum.frequencies_by(events, & &1.event_type),
      first_event: List.first(events),
      last_event: List.last(events),
      duration: calculate_draft_duration(events)
    }
  end

  # Private helper functions for event logging

  defp format_event_description(%DraftEvent{event_type: "draft_created"}), do: "Draft was created"
  defp format_event_description(%DraftEvent{event_type: "draft_started"}), do: "Draft was started"

  defp format_event_description(%DraftEvent{event_type: "draft_completed"}),
    do: "Draft was completed"

  defp format_event_description(%DraftEvent{event_type: "draft_cancelled"}),
    do: "Draft was cancelled"

  defp format_event_description(%DraftEvent{
         event_type: "team_added",
         event_data: %{"team_name" => name}
       }),
       do: "Team '#{name}' was added"

  defp format_event_description(%DraftEvent{
         event_type: "team_removed",
         event_data: %{"team_name" => name}
       }),
       do: "Team '#{name}' was removed"

  defp format_event_description(%DraftEvent{
         event_type: "player_added",
         event_data: %{"player_name" => name}
       }),
       do: "Player '#{name}' was added"

  defp format_event_description(%DraftEvent{
         event_type: "player_removed",
         event_data: %{"player_name" => name}
       }),
       do: "Player '#{name}' was removed"

  defp format_event_description(%DraftEvent{
         event_type: "pick_made",
         event_data: %{"pick_number" => num}
       }),
       do: "Pick ##{num} was made"

  defp format_event_description(%DraftEvent{
         event_type: "pick_undone",
         event_data: %{"pick_number" => num}
       }),
       do: "Pick ##{num} was undone"

  defp format_event_description(%DraftEvent{event_type: event_type}),
    do: "#{String.replace(event_type, "_", " ") |> String.capitalize()}"

  defp calculate_draft_duration(events) when length(events) < 2, do: nil

  defp calculate_draft_duration(events) do
    first_time = List.first(events).inserted_at
    last_time = List.last(events).inserted_at
    DateTime.diff(last_time, first_time, :second)
  end

  ## Spectator Controls management

  @doc """
  Gets spectator controls for a draft.
  """
  def get_spectator_controls(draft_id) do
    case Repo.get_by(SpectatorControls, draft_id: draft_id) do
      nil -> create_default_spectator_controls(draft_id)
      controls -> {:ok, controls}
    end
  end

  @doc """
  Updates spectator controls for a draft.
  """
  def update_spectator_controls(draft_id, attrs) do
    case get_spectator_controls(draft_id) do
      {:ok, controls} ->
        controls
        |> SpectatorControls.changeset(attrs)
        |> Repo.update()

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Toggles team name display for spectators.
  """
  def toggle_team_names_display(draft_id) do
    with {:ok, controls} <- get_spectator_controls(draft_id) do
      update_spectator_controls(draft_id, %{show_team_names: !controls.show_team_names})
    end
  end

  @doc """
  Toggles player names display for spectators.
  """
  def toggle_player_names_display(draft_id) do
    with {:ok, controls} <- get_spectator_controls(draft_id) do
      update_spectator_controls(draft_id, %{show_player_names: !controls.show_player_names})
    end
  end

  @doc """
  Toggles pick timer display for spectators.
  """
  def toggle_pick_timer_display(draft_id) do
    with {:ok, controls} <- get_spectator_controls(draft_id) do
      update_spectator_controls(draft_id, %{show_pick_timer: !controls.show_pick_timer})
    end
  end

  @doc """
  Updates the overlay theme for spectators.
  """
  def update_overlay_theme(draft_id, theme)
      when theme in ["default", "dark", "minimal", "tournament"] do
    update_spectator_controls(draft_id, %{overlay_theme: theme})
  end

  @doc """
  Updates the pick timer duration (in seconds).
  """
  def update_pick_timer_duration(draft_id, duration) when is_integer(duration) and duration > 0 do
    update_spectator_controls(draft_id, %{pick_timer_duration: duration})
  end

  @doc """
  Resets spectator controls to default values.
  """
  def reset_spectator_controls(draft_id) do
    update_spectator_controls(draft_id, %{
      show_team_names: true,
      show_player_names: true,
      show_pick_timer: true,
      overlay_theme: "default",
      pick_timer_duration: 60
    })
  end

  @doc """
  Gets spectator-friendly data for overlay display.
  """
  def get_spectator_data(draft_id) do
    with {:ok, controls} <- get_spectator_controls(draft_id),
         draft <- get_draft!(draft_id) |> Repo.preload([:teams, :picks]) do
      teams =
        if controls.show_team_names do
          draft.teams
        else
          draft.teams
          |> Enum.map(fn team -> %{team | name: "Team #{team.pick_order_position}"} end)
        end

      picks =
        if controls.show_player_names do
          list_picks(draft_id)
        else
          list_picks(draft_id)
          |> Enum.map(fn pick -> %{pick | player: %{pick.player | display_name: "Player"}} end)
        end

      %{
        draft: draft,
        teams: teams,
        picks: picks,
        controls: controls,
        current_team: get_next_team_to_pick(draft),
        current_pick_number: get_current_pick_number(draft_id)
      }
    end
  end

  # Private helper functions for spectator controls

  defp create_default_spectator_controls(draft_id) do
    %SpectatorControls{}
    |> SpectatorControls.changeset(%{
      draft_id: draft_id,
      show_team_names: true,
      show_player_names: true,
      show_pick_timer: true,
      overlay_theme: "default",
      pick_timer_duration: 60
    })
    |> Repo.insert()
  end

  ## Chat management

  @doc """
  Returns the list of chat messages for a draft (global chat).
  """
  def list_chat_messages(draft_id) do
    from(m in ChatMessage,
      where: m.draft_id == ^draft_id and is_nil(m.team_id),
      order_by: [asc: m.inserted_at],
      limit: 100
    )
    |> Repo.all()
  end

  @doc """
  Returns the list of chat messages for a specific team.
  """
  def list_team_chat_messages(draft_id, team_id) do
    from(m in ChatMessage,
      where: m.draft_id == ^draft_id and m.team_id == ^team_id,
      order_by: [asc: m.inserted_at],
      limit: 100
    )
    |> Repo.all()
  end

  @doc """
  Returns recent chat messages (last N messages) for a draft.
  """
  def get_recent_chat_messages(draft_id, limit \\ 50) do
    from(m in ChatMessage,
      where: m.draft_id == ^draft_id and is_nil(m.team_id),
      order_by: [desc: m.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
    |> Enum.reverse()
  end

  @doc """
  Returns recent team chat messages (last N messages) for a team.
  """
  def get_recent_team_chat_messages(draft_id, team_id, limit \\ 50) do
    from(m in ChatMessage,
      where: m.draft_id == ^draft_id and m.team_id == ^team_id,
      order_by: [desc: m.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
    |> Enum.reverse()
  end

  ## Pick Queue

  @doc """
  Queues a pick for a team when it's not their turn.
  """
  def queue_pick(draft_id, team_id, player_id, queued_by_token, champion_id \\ nil) do
    with {:ok, draft} <- get_draft_if_active(draft_id),
         {:ok, team} <- validate_team_exists(draft, team_id),
         {:ok, _token_valid} <- validate_team_token(team, queued_by_token),
         {:ok, _player} <- validate_player_available(draft_id, player_id),
         {:ok, _not_queued} <- validate_player_not_already_queued(draft_id, team_id, player_id) do
      
      # Get next available queue position for this team
      next_position = get_next_queue_position(draft_id, team_id)
      
      %PickQueue{}
      |> PickQueue.changeset(%{
        draft_id: draft_id,
        team_id: team_id,
        player_id: player_id,
        champion_id: champion_id,
        queued_at: DateTime.utc_now(),
        queued_by_token: queued_by_token,
        status: "queued",
        queue_position: next_position
      })
      |> Repo.insert()
      |> case do
        {:ok, queued_pick} ->
          # Telemetry for queue pick added
          :telemetry.execute([:ace_app, :queue, :picks_added], %{count: 1}, %{
            draft_id: draft_id,
            team_id: team_id,
            queue_position: next_position
          })
          
          # Send team chat message about the queued pick
          queued_pick_with_associations = queued_pick |> Repo.preload([:player, :team])

          send_chat_message(
            draft_id,
            "system",
            "Draft System",
            "Queued #{queued_pick_with_associations.player.display_name} (position #{next_position}) - will be picked automatically when it's your turn!",
            team_id
          )

          {:ok, queued_pick}

        error ->
          error
      end
    end
  end

  @doc """
  Gets the next available queue position for a team.
  """
  def get_next_queue_position(draft_id, team_id) do
    max_position = 
      from(pq in PickQueue,
        where: pq.draft_id == ^draft_id and pq.team_id == ^team_id and pq.status == "queued",
        select: max(pq.queue_position)
      )
      |> Repo.one()
    
    case max_position do
      nil -> 1
      pos -> pos + 1
    end
  end

  @doc """
  Gets the next queued pick for a team (lowest queue position).
  """
  def get_next_queued_pick(draft_id, team_id) do
    from(pq in PickQueue,
      where: pq.draft_id == ^draft_id and pq.team_id == ^team_id and pq.status == "queued",
      preload: [:player, :team, :champion],
      order_by: [asc: pq.queue_position],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Gets all queued picks for a team, ordered by queue position.
  """
  def get_team_queued_picks(draft_id, team_id) do
    from(pq in PickQueue,
      where: pq.draft_id == ^draft_id and pq.team_id == ^team_id and pq.status == "queued",
      preload: [:player, :team, :champion],
      order_by: [asc: pq.queue_position]
    )
    |> Repo.all()
  end

  @doc """
  Gets the queued pick for a team if one exists (backwards compatibility).
  """
  def get_queued_pick(draft_id, team_id) do
    get_next_queued_pick(draft_id, team_id)
  end

  def get_queued_pick_by_id(pick_id) do
    case Repo.get(PickQueue, pick_id) do
      nil -> {:error, :pick_not_found}
      pick -> {:ok, Repo.preload(pick, [:player, :team, :champion])}
    end
  end

  @doc """
  Gets all queued picks for a draft.
  """
  def list_queued_picks(draft_id) do
    from(pq in PickQueue,
      where: pq.draft_id == ^draft_id and pq.status == "queued",
      preload: [:player, :team, :champion],
      order_by: [asc: pq.queued_at]
    )
    |> Repo.all()
  end

  @doc """
  Executes a queued pick when it's the team's turn.
  """
  def execute_queued_pick(draft_id, team_id) do
    case get_next_queued_pick(draft_id, team_id) do
      nil ->
        {:error, :no_queued_pick}

      queued_pick ->
        Repo.transaction(fn ->
          # Execute the actual pick
          case make_pick(draft_id, team_id, queued_pick.player_id, queued_pick.champion_id, true) do
            {:ok, pick} ->
              # Mark queue entry as executed
              queued_pick
              |> PickQueue.changeset(%{status: "executed"})
              |> Repo.update!()

              # Reorder remaining queue positions for this team
              reorder_team_queue_after_execution(draft_id, team_id, queued_pick.queue_position)

              pick

            {:error, reason} ->
              Repo.rollback(reason)
          end
        end)
    end
  end

  # Reorders team queue positions after a pick is executed or cancelled.
  defp reorder_team_queue_after_execution(draft_id, team_id, executed_position) do
    from(pq in PickQueue,
      where: pq.draft_id == ^draft_id and pq.team_id == ^team_id and 
             pq.status == "queued" and pq.queue_position > ^executed_position
    )
    |> Repo.update_all(inc: [queue_position: -1])
  end

  @doc """
  Cancels a queued pick for a team by position (defaults to next pick).
  """
  def cancel_queued_pick(draft_id, team_id, token, queue_position \\ 1) do
    case get_queued_pick_by_position(draft_id, team_id, queue_position) do
      nil ->
        {:error, :no_queued_pick}

      queued_pick ->
        with {:ok, team} <- get_team_by_id(team_id),
             {:ok, _token_valid} <- validate_team_token(team, token) do
          Repo.transaction(fn ->
            # Cancel the pick
            updated_pick = 
              queued_pick
              |> PickQueue.changeset(%{status: "cancelled"})
              |> Repo.update!()

            # Reorder remaining queue positions
            reorder_team_queue_after_execution(draft_id, team_id, queued_pick.queue_position)

            updated_pick
          end)
        end
    end
  end

  @doc """
  Gets a queued pick by position for a team.
  """
  def get_queued_pick_by_position(draft_id, team_id, queue_position) do
    from(pq in PickQueue,
      where: pq.draft_id == ^draft_id and pq.team_id == ^team_id and 
             pq.status == "queued" and pq.queue_position == ^queue_position,
      preload: [:player, :team, :champion]
    )
    |> Repo.one()
  end

  def cancel_queued_pick_by_id(draft_id, pick_id, team_id, token) do
    with {:ok, queued_pick} <- get_queued_pick_by_id(pick_id),
         {:ok, team} <- get_team_by_id(team_id),
         {:ok, _token_valid} <- validate_team_token(team, token),
         true <- queued_pick.draft_id == draft_id,
         true <- queued_pick.team_id == team_id do
      queued_pick
      |> PickQueue.changeset(%{status: "cancelled"})
      |> Repo.update()
    else
      {:error, reason} -> {:error, reason}
      false -> {:error, :pick_not_found}
      nil -> {:error, :pick_not_found}
    end
  end

  @doc """
  Clears all queued picks for a team.
  """
  def clear_team_queue(draft_id, team_id, token) do
    with {:ok, team} <- get_team_by_id(team_id),
         {:ok, _token_valid} <- validate_team_token(team, token) do
      
      # Get count of picks to clear
      count = from(pq in PickQueue,
        where: pq.draft_id == ^draft_id and pq.team_id == ^team_id and pq.status == "queued",
        select: count(pq.id)
      ) |> Repo.one()

      case count do
        0 -> {:error, :no_queued_picks}
        _ ->
          # Cancel all queued picks for this team
          {updated_count, _} = from(pq in PickQueue,
            where: pq.draft_id == ^draft_id and pq.team_id == ^team_id and pq.status == "queued"
          ) |> Repo.update_all(set: [status: "cancelled"])

          {:ok, updated_count}
      end
    end
  end

  @doc """
  Clears a picked player from all other teams' queues to handle conflicts.
  """
  def clear_player_from_other_queues(draft_id, picking_team_id, player_id) do
    # Get the affected queues before cancelling them (to get their positions)
    affected_queues =
      from(q in PickQueue,
        where:
          q.draft_id == ^draft_id and
            q.player_id == ^player_id and
            q.team_id != ^picking_team_id and
            q.status == "queued",
        preload: [:team, :player]
      )
      |> Repo.all()

    # Cancel the conflicting picks
    from(q in PickQueue,
      where:
        q.draft_id == ^draft_id and
          q.player_id == ^player_id and
          q.team_id != ^picking_team_id and
          q.status == "queued"
    )
    |> Repo.update_all(set: [status: "cancelled"])

    # Reorder queue positions for each affected team
    Enum.each(affected_queues, fn cancelled_queue ->
      reorder_team_queue_after_execution(draft_id, cancelled_queue.team_id, cancelled_queue.queue_position)
      
      Phoenix.PubSub.broadcast(
        AceApp.PubSub,
        "draft:#{draft_id}",
        {:queue_cleared_conflict, cancelled_queue.team_id, cancelled_queue.player_id}
      )
    end)
  end

  @doc """
  Checks if it's a team's turn to pick and executes any queued pick.
  """
  def process_team_turn(draft_id) do
    with {:ok, draft} <- get_draft_if_active(draft_id),
         next_team when not is_nil(next_team) <- get_next_team_to_pick(draft) do
      case execute_queued_pick(draft_id, next_team.id) do
        {:ok, pick} ->
          # Telemetry for queued pick executed
          :telemetry.execute([:ace_app, :queue, :picks_executed], %{count: 1}, %{
            draft_id: draft_id,
            team_id: next_team.id,
            pick_number: pick.pick_number
          })
          
          # Broadcast that a queued pick was executed
          Phoenix.PubSub.broadcast(
            AceApp.PubSub,
            "draft:#{draft_id}",
            {:queued_pick_executed, pick}
          )

          {:ok, pick}

        {:error, :no_queued_pick} ->
          {:ok, :no_queued_pick}

        {:error, reason} ->
          {:error, reason}
      end
    else
      _ -> {:ok, :no_action_needed}
    end
  end

  @doc """
  Enhanced version of process_team_turn that also handles timer logic.
  Checks if it's a team's turn to pick, executes any queued pick, or starts a timer.
  """
  def process_team_turn_with_timer(draft_id) do
    # Check if there are any queued picks at all before starting the loop
    case list_queued_picks(draft_id) do
      [] -> 
        # No queued picks, go straight to timer logic
        start_timer_for_current_team(draft_id)
      _queued_picks ->
        # Keep processing queued picks until none remain, then start timer
        process_team_turn_loop(draft_id)
    end
  end

  defp start_timer_for_current_team(draft_id) do
    with {:ok, draft} <- get_draft_if_active(draft_id),
         next_team when not is_nil(next_team) <- get_next_team_to_pick(draft) do
      draft_with_preload = get_draft_with_associations!(draft_id)
      timer_duration = draft_with_preload.pick_timer_seconds
      
      case TimerManager.start_pick_timer(draft_id, next_team.id, timer_duration) do
        {:ok, :timer_started} ->
          # Broadcast that timer started for this team
          Phoenix.PubSub.broadcast(
            AceApp.PubSub,
            "draft:#{draft_id}",
            {:timer_started, %{team_id: next_team.id, duration: timer_duration}}
          )
          
          {:ok, :timer_started}
        
        {:error, reason} ->
          {:error, reason}
      end
    else
      error -> error
    end
  end

  defp process_team_turn_loop(draft_id) do
    with {:ok, draft} <- get_draft_if_active(draft_id),
         next_team when not is_nil(next_team) <- get_next_team_to_pick(draft) do
      case execute_queued_pick(draft_id, next_team.id) do
        {:ok, pick} ->
          # Telemetry for queued pick executed
          :telemetry.execute([:ace_app, :queue, :picks_executed], %{count: 1}, %{
            draft_id: draft_id,
            team_id: next_team.id,
            pick_number: pick.pick_number
          })
          
          # Broadcast that a queued pick was executed
          Phoenix.PubSub.broadcast(
            AceApp.PubSub,
            "draft:#{draft_id}",
            {:queued_pick_executed, pick}
          )

          # Continue processing - check if next team has queued picks
          # BUT: Add a small delay to prevent infinite tight loops
          :timer.sleep(100)
          process_team_turn_loop(draft_id)

        {:error, :no_queued_pick} ->
          # No queued pick, start timer for this team
          draft_with_preload = get_draft_with_associations!(draft_id)
          timer_duration = draft_with_preload.pick_timer_seconds
          
          case TimerManager.start_pick_timer(draft_id, next_team.id, timer_duration) do
            {:ok, :timer_started} ->
              # Broadcast that timer started for this team
              Phoenix.PubSub.broadcast(
                AceApp.PubSub,
                "draft:#{draft_id}",
                {:timer_started, %{team_id: next_team.id, duration: timer_duration}}
              )
              
              {:ok, :timer_started}
            
            {:error, reason} ->
              {:error, reason}
          end

        {:error, reason} ->
          {:error, reason}
      end
    else
      _ -> {:ok, :no_action_needed}
    end
  end

  @doc """
  Sends a message to the global draft chat.
  """
  def send_chat_message(draft_id, sender_type, sender_name, content, metadata \\ %{}) do
    %ChatMessage{}
    |> ChatMessage.changeset(%{
      draft_id: draft_id,
      content: content,
      sender_type: sender_type,
      sender_name: sender_name,
      message_type: "message",
      metadata: metadata
    })
    |> Repo.insert()
    |> case do
      {:ok, message} ->
        log_draft_event(draft_id, "chat_message_sent", %{
          sender_type: sender_type,
          sender_name: sender_name,
          message_length: String.length(content)
        })
        
        # Telemetry for chat message sent
        :telemetry.execute([:ace_app, :chat, :messages], %{count: 1}, %{
          draft_id: draft_id,
          sender_type: sender_type,
          message_length: String.length(content)
        })

        {:ok, message}

      error ->
        error
    end
  end

  @doc """
  Sends a message to a specific team chat.
  """
  def send_team_chat_message(
        draft_id,
        team_id,
        sender_type,
        sender_name,
        content,
        metadata \\ %{}
      ) do
    %ChatMessage{}
    |> ChatMessage.changeset(%{
      draft_id: draft_id,
      team_id: team_id,
      content: content,
      sender_type: sender_type,
      sender_name: sender_name,
      message_type: "message",
      metadata: metadata
    })
    |> Repo.insert()
    |> case do
      {:ok, message} ->
        log_draft_event(draft_id, "team_chat_message_sent", %{
          team_id: team_id,
          sender_type: sender_type,
          sender_name: sender_name,
          message_length: String.length(content)
        })

        {:ok, message}

      error ->
        error
    end
  end

  @doc """
  Sends a system message (automated notification).
  """
  def send_system_message(draft_id, content, metadata \\ %{}) do
    %ChatMessage{}
    |> ChatMessage.changeset(%{
      draft_id: draft_id,
      content: content,
      sender_type: "system",
      sender_name: "System",
      message_type: "system",
      metadata: metadata
    })
    |> Repo.insert()
  end

  @doc """
  Sends an announcement message (admin broadcast).
  """
  def send_announcement(draft_id, sender_name, content, metadata \\ %{}) do
    %ChatMessage{}
    |> ChatMessage.changeset(%{
      draft_id: draft_id,
      content: content,
      sender_type: "organizer",
      sender_name: sender_name,
      message_type: "announcement",
      metadata: metadata
    })
    |> Repo.insert()
    |> case do
      {:ok, message} ->
        log_draft_event(draft_id, "announcement_sent", %{
          sender_name: sender_name,
          message_length: String.length(content)
        })

        {:ok, message}

      error ->
        error
    end
  end

  @doc """
  Gets a single chat message.
  """
  def get_chat_message!(id), do: Repo.get!(ChatMessage, id)

  @doc """
  Deletes a chat message (admin function).
  """
  def delete_chat_message(%ChatMessage{} = message) do
    Repo.delete(message)
  end

  @doc """
  Gets chat statistics for a draft.
  """
  def get_chat_stats(draft_id) do
    messages = from(m in ChatMessage, where: m.draft_id == ^draft_id) |> Repo.all()

    %{
      total_messages: length(messages),
      global_messages: Enum.count(messages, &is_nil(&1.team_id)),
      team_messages: Enum.count(messages, &(!is_nil(&1.team_id))),
      messages_by_type: Enum.frequencies_by(messages, & &1.message_type),
      messages_by_sender_type: Enum.frequencies_by(messages, & &1.sender_type),
      unique_senders: messages |> Enum.map(& &1.sender_name) |> Enum.uniq() |> length(),
      first_message: messages |> Enum.min_by(& &1.inserted_at, DateTime, fn -> nil end),
      last_message: messages |> Enum.max_by(& &1.inserted_at, DateTime, fn -> nil end)
    }
  end

  @doc """
  Clears all chat messages for a draft (admin function).
  """
  def clear_chat_messages(draft_id) do
    from(m in ChatMessage, where: m.draft_id == ^draft_id)
    |> Repo.delete_all()

    log_draft_event(draft_id, "chat_cleared", %{})
  end

  @doc """
  Clears team chat messages for a specific team (admin function).
  """
  def clear_team_chat_messages(draft_id, team_id) do
    from(m in ChatMessage, where: m.draft_id == ^draft_id and m.team_id == ^team_id)
    |> Repo.delete_all()

    log_draft_event(draft_id, "team_chat_cleared", %{team_id: team_id})
  end

  @doc """
  Gets all chat channels available for a draft (global + team channels).
  """
  def get_chat_channels(draft_id) do
    teams = list_teams(draft_id)

    global_channel = %{
      id: "global",
      name: "Global Chat",
      type: "global",
      team_id: nil,
      recent_messages: get_recent_chat_messages(draft_id, 10)
    }

    team_channels =
      Enum.map(teams, fn team ->
        %{
          id: "team_#{team.id}",
          name: "#{team.name} Chat",
          type: "team",
          team_id: team.id,
          recent_messages: get_recent_team_chat_messages(draft_id, team.id, 10)
        }
      end)

    [global_channel | team_channels]
  end

  ## Draft Snapshots

  @doc """
  Creates a snapshot of the current draft state for rollback purposes.
  """
  def create_draft_snapshot(draft_id, pick_number, created_by_user_id \\ nil, snapshot_name \\ nil) do
    draft = get_draft_with_associations!(draft_id)
    teams = list_teams(draft_id)
    picks = list_picks(draft_id)

    attrs = %{
      draft_id: draft_id,
      pick_number: pick_number,
      snapshot_name: snapshot_name || "Pick #{pick_number}",
      draft_state: serialize_draft_state(draft),
      teams_state: serialize_teams_state(teams),
      picks_state: serialize_picks_state(picks),
      created_by_user_id: created_by_user_id
    }

    %DraftSnapshot{}
    |> DraftSnapshot.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a specific draft snapshot by pick number.
  """
  def get_draft_snapshot(draft_id, pick_number) do
    Repo.get_by(DraftSnapshot, draft_id: draft_id, pick_number: pick_number)
  end

  @doc """
  Lists all snapshots for a draft, ordered by pick number.
  """
  def list_draft_snapshots(draft_id) do
    from(s in DraftSnapshot,
      where: s.draft_id == ^draft_id,
      order_by: [asc: s.pick_number]
    )
    |> Repo.all()
  end

  @doc """
  Rollback draft to a specific pick number by restoring state from snapshot.
  """
  def rollback_draft_to_pick(draft_id, target_pick_number, performed_by, performed_by_role) do
    Repo.transaction(fn ->
      # Get the snapshot to restore
      snapshot = get_draft_snapshot(draft_id, target_pick_number)
      
      if snapshot do
        # Delete picks after target pick number
        from(p in Pick,
          where: p.draft_id == ^draft_id and p.pick_number > ^target_pick_number
        )
        |> Repo.delete_all()

        # Clear any queued picks (they become invalid after rollback)
        from(q in PickQueue,
          where: q.draft_id == ^draft_id
        )
        |> Repo.delete_all()

        # Update draft state from snapshot
        draft = get_draft!(draft_id)
        updated_draft = Draft.changeset(draft, snapshot.draft_state)
        case Repo.update(updated_draft) do
          {:ok, draft} ->
            # Calculate picks removed (we know the target was reached)
            current_pick_count = get_next_pick_number(draft_id)
            picks_removed = current_pick_count - target_pick_number
            
            # Log the rollback action
            log_audit_event(draft_id, "pick_rollback", %{
              target_pick_number: target_pick_number,
              picks_removed: picks_removed,
              restored_from_snapshot: snapshot.id
            }, performed_by, performed_by_role)

            # Broadcast rollback event
            Phoenix.PubSub.broadcast(
              AceApp.PubSub,
              "draft:#{draft_id}",
              {:draft_rollback, %{target_pick_number: target_pick_number, draft: draft}}
            )

            {:ok, draft}
          {:error, changeset} -> Repo.rollback(changeset)
        end
      else
        Repo.rollback("Snapshot not found for pick #{target_pick_number}")
      end
    end)
  end

  ## Draft Audit Logging

  @doc """
  Logs an audit event for draft actions.
  """
  def log_audit_event(draft_id, action_type, action_data, performed_by \\ nil, performed_by_role \\ "system", client_info \\ %{}) do
    attrs = %{
      draft_id: draft_id,
      action_type: action_type,
      action_data: action_data,
      performed_by: performed_by,
      performed_by_role: performed_by_role,
      client_info: client_info
    }

    %DraftAuditLog{}
    |> DraftAuditLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets audit log entries for a draft.
  """
  def list_audit_log(draft_id, limit \\ 100) do
    from(a in DraftAuditLog,
      where: a.draft_id == ^draft_id,
      order_by: [desc: a.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Gets audit log entries for a specific action type.
  """
  def list_audit_log_by_action(draft_id, action_type, limit \\ 50) do
    from(a in DraftAuditLog,
      where: a.draft_id == ^draft_id and a.action_type == ^action_type,
      order_by: [desc: a.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  # Private helper functions for serialization

  defp serialize_draft_state(draft) do
    # Calculate current pick number from existing picks
    current_pick_number = length(draft.picks || [])
    
    %{
      id: draft.id,
      name: draft.name,
      status: draft.status,
      format: draft.format,
      pick_timer_seconds: draft.pick_timer_seconds,
      current_turn_team_id: draft.current_turn_team_id,
      current_pick_deadline: draft.current_pick_deadline,
      current_pick_number: current_pick_number,
      timer_status: draft.timer_status,
      timer_remaining_seconds: draft.timer_remaining_seconds,
      timer_started_at: draft.timer_started_at
    }
  end

  defp serialize_teams_state(teams) do
    team_list = Enum.map(teams, fn team ->
      %{
        id: team.id,
        name: team.name,
        logo_url: team.logo_url,
        pick_order_position: team.pick_order_position,
        is_ready: team.is_ready
      }
    end)
    
    %{teams: team_list}
  end

  defp serialize_picks_state(picks) do
    pick_list = Enum.map(picks, fn pick ->
      %{
        id: pick.id,
        team_id: pick.team_id,
        player_id: pick.player_id,
        champion_id: pick.champion_id,
        pick_number: pick.pick_number,
        round_number: pick.round_number,
        picked_at: pick.picked_at,
        pick_duration_ms: pick.pick_duration_ms
      }
    end)
    
    %{picks: pick_list}
  end
end
