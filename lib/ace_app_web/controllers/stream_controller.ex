defmodule AceAppWeb.StreamController do
  use AceAppWeb, :controller
  
  import Ecto.Query
  alias AceApp.Drafts
  
  @doc """
  Stream overlay data for OBS browser sources.
  Returns JSON data optimized for real-time overlay graphics.
  """
  def overlay(conn, %{"id" => id}) do
    case get_draft_by_id(id) do
      {:ok, draft} ->
        overlay_data = build_overlay_data(draft)
        
        conn
        |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
        |> put_resp_header("pragma", "no-cache")
        |> put_resp_header("expires", "0")
        |> put_resp_header("access-control-allow-origin", "*")
        |> json(overlay_data)
        
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Draft not found"})
    end
  end

  @doc """
  Team comparison graphics for side-by-side display.
  Shows team rosters, logos, and pick progress.
  """
  def teams(conn, %{"id" => id}) do
    case get_draft_by_id(id) do
      {:ok, draft} ->
        teams_data = build_teams_comparison_data(draft)
        
        conn
        |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
        |> put_resp_header("access-control-allow-origin", "*")
        |> json(teams_data)
        
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Draft not found"})
    end
  end

  @doc """
  Pick timeline for horizontal ticker display.
  Shows recent picks and upcoming turn information.
  """
  def timeline(conn, %{"id" => id}) do
    case get_draft_by_id(id) do
      {:ok, draft} ->
        timeline_data = build_timeline_data(draft)
        
        conn
        |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
        |> put_resp_header("access-control-allow-origin", "*")
        |> json(timeline_data)
        
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Draft not found"})
    end
  end

  @doc """
  Current pick status with large team branding.
  Shows whose turn it is with timer and team graphics.
  """
  def current(conn, %{"id" => id}) do
    case get_draft_by_id(id) do
      {:ok, draft} ->
        current_pick_data = build_current_pick_data(draft)
        
        conn
        |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
        |> put_resp_header("access-control-allow-origin", "*")
        |> json(current_pick_data)
        
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Draft not found"})
    end
  end

  @doc """
  Roster view showing all teams and their complete rosters.
  Provides comprehensive team overview for tournament display.
  """
  def roster(conn, %{"id" => id}) do
    case get_draft_by_id(id) do
      {:ok, draft} ->
        roster_data = build_roster_data(draft)
        
        conn
        |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
        |> put_resp_header("pragma", "no-cache")
        |> put_resp_header("expires", "0")
        |> put_resp_header("access-control-allow-origin", "*")
        |> json(roster_data)
        
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Draft not found"})
    end
  end

  @doc """
  Available players view showing remaining players grouped by role.
  Shows which players are still available for picking.
  """
  def available_players(conn, %{"id" => id}) do
    case get_draft_by_id(id) do
      {:ok, draft} ->
        available_data = build_available_players_data(draft)
        
        conn
        |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
        |> put_resp_header("pragma", "no-cache")
        |> put_resp_header("expires", "0")
        |> put_resp_header("access-control-allow-origin", "*")
        |> json(available_data)
        
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Draft not found"})
    end
  end

  # Private helper functions

  defp get_draft_by_id(id) do
    case Integer.parse(id) do
      {draft_id, ""} ->
        try do
          draft_with_data = Drafts.get_draft_with_associations!(draft_id)
          {:ok, draft_with_data}
        rescue
          Ecto.NoResultsError ->
            {:error, :not_found}
        end
      _ ->
        {:error, :not_found}
    end
  end

  defp build_overlay_data(draft) do
    # Use draft associations loaded from get_draft_with_associations! instead of separate queries
    picks = case draft.picks do
      %Ecto.Association.NotLoaded{} ->
        Drafts.list_picks(draft.id) |> Enum.sort_by(& &1.pick_number)
      picks ->
        picks |> Enum.sort_by(& &1.pick_number)
    end
    
    # Get the correct format module and generate draft order
    format_module = AceApp.Drafts.DraftFormat.get_format_module(draft.format, draft.draft_variant || :standard)
    draft_order = format_module.generate_full_draft_order(draft.teams)
    # Override picks_per_team if captains are required (captain_mode or captains_required flag)
    picks_per_team = if draft.format == :captain_mode or draft.captains_required, do: 4, else: format_module.picks_per_team()
    
    current_team = get_current_team(draft)
    
    # Always load players with champions for precaching
    all_players = AceApp.Repo.all(
      from p in AceApp.Drafts.Player,
      where: p.draft_id == ^draft.id,
      preload: [:champion]
    )
    
    # Build pre-cache data for all player-assigned champions
    precache_images = all_players
    |> Enum.filter(fn player -> player.champion != nil end)
    |> Enum.map(fn player ->
      skin_data = if player.preferred_skin_id do
        skin = AceApp.LoL.get_champion_skin(player.champion.id, player.preferred_skin_id)
        if skin do
          %{
            skin_name: skin.name,
            splash_url: AceApp.LoL.get_skin_splash_url(player.champion, skin)
          }
        else
          AceApp.LoL.get_random_champion_skin_with_url(player.champion)
        end
      else
        AceApp.LoL.get_random_champion_skin_with_url(player.champion)
      end
      
      %{
        player_name: player.display_name,
        champion: %{
          id: player.champion.id,
          name: player.champion.name,
          title: player.champion.title,
          splash_url: skin_data.splash_url,
          skin_name: skin_data.skin_name
        }
      }
    end)
    
    %{
      draft: %{
        id: draft.id,
        name: draft.name,
        status: draft.status,
        format: draft.format,
        draft_variant: draft.draft_variant,
        pick_timer_seconds: draft.pick_timer_seconds,
        current_pick_number: length(picks) + 1,
        total_picks: length(draft.teams) * picks_per_team,
        picks_per_team: picks_per_team
      },
      teams: Enum.map(draft.teams, &format_team_for_stream/1),
      draft_order: Enum.map(draft_order, fn slot ->
        %{
          round: slot.round,
          pick_number: slot.pick_number,
          position_in_round: slot.position_in_round,
          team_id: slot.team.id,
          team_name: slot.team.name,
          team_pick_order_position: slot.team.pick_order_position
        }
      end),
      recent_picks: picks |> Enum.take(-5) |> Enum.map(&format_pick_for_stream/1),
      all_picks: picks |> Enum.map(&format_pick_for_stream/1),
      precache_images: precache_images,
      current_turn: current_team && format_current_turn(current_team, draft),
      timer: format_timer_data(draft),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp build_teams_comparison_data(draft) do
    # Get all picks once and group by team to avoid N+1 queries
    all_picks = case draft.picks do
      %Ecto.Association.NotLoaded{} ->
        Drafts.list_picks(draft.id)
      picks ->
        picks
    end
    
    picks_by_team = Enum.group_by(all_picks, & &1.team_id)
    
    teams_with_picks = Enum.map(draft.teams, fn team ->
      team_picks = Map.get(picks_by_team, team.id, [])
      
      %{
        id: team.id,
        name: team.name,
        logo_url: team.logo_url,
        pick_order_position: team.pick_order_position,
        color: get_team_color(team.pick_order_position),
        picks: Enum.map(team_picks, &format_pick_for_stream/1),
        picks_completed: length(team_picks),
        picks_remaining: 5 - length(team_picks)
      }
    end)
    |> Enum.sort_by(& &1.pick_order_position)

    %{
      draft_name: draft.name,
      draft_status: draft.status,
      teams: teams_with_picks,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp build_timeline_data(draft) do
    # Use pre-loaded picks if available
    picks = case draft.picks do
      %Ecto.Association.NotLoaded{} ->
        Drafts.list_picks(draft.id) |> Enum.sort_by(& &1.pick_number)
      picks ->
        picks |> Enum.sort_by(& &1.pick_number)
    end
    
    current_team = get_current_team(draft)
    
    %{
      recent_picks: picks |> Enum.take(-8) |> Enum.map(&format_pick_for_timeline/1),
      upcoming_turn: current_team && %{
        team_name: current_team.name,
        team_logo: current_team.logo_url,
        pick_number: length(picks) + 1,
        color: get_team_color(current_team.pick_order_position)
      },
      draft_progress: %{
        completed_picks: length(picks),
        total_picks: length(draft.teams) * 5,
        percentage: round((length(picks) / (length(draft.teams) * 5)) * 100)
      },
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp build_current_pick_data(draft) do
    current_team = get_current_team(draft)
    picks_count = Drafts.count_picks(draft.id)
    
    if current_team do
      %{
        active: true,
        team: %{
          id: current_team.id,
          name: current_team.name,
          logo_url: current_team.logo_url,
          color: get_team_color(current_team.pick_order_position)
        },
        pick_info: %{
          number: picks_count + 1,
          round: div(picks_count, length(draft.teams)) + 1,
          position_in_round: rem(picks_count, length(draft.teams)) + 1
        },
        timer: format_timer_data(draft),
        draft_name: draft.name,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    else
      %{
        active: false,
        draft_status: draft.status,
        draft_name: draft.name,
        message: case draft.status do
          :setup -> "Draft Setup in Progress"
          :completed -> "Draft Complete"
          :paused -> "Draft Paused"
          _ -> "Waiting for Draft to Begin"
        end,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    end
  end

  defp build_roster_data(draft) do
    # Calculate picks per team based on captain requirement
    picks_per_team = if draft.format == :captain_mode or draft.captains_required, do: 4, else: 5
    
    teams_with_rosters = Enum.map(draft.teams, fn team ->
      team_picks = Drafts.get_team_picks(draft.id, team.id)
      team_captain = Drafts.get_team_captain(team.id)
      
      %{
        id: team.id,
        name: team.name,
        logo_url: team.logo_url,
        pick_order_position: team.pick_order_position,
        color: get_team_color(team.pick_order_position),
        captain_token: team.captain_token,
        is_ready: team.is_ready,
        captain: if team_captain do
          %{
            id: team_captain.id,
            display_name: team_captain.display_name,
            preferred_roles: team_captain.preferred_roles
          }
        else
          nil
        end,
        roster: Enum.map(team_picks, fn pick ->
          pick = Drafts.preload_pick_associations(pick)
          %{
            pick_number: pick.pick_number,
            round_number: pick.round_number,
            player: %{
              id: pick.player.id,
              display_name: pick.player.display_name,
              preferred_roles: pick.player.preferred_roles,
              custom_stats: pick.player.custom_stats,
              organizer_notes: pick.player.organizer_notes,
              is_captain: pick.player.is_captain
            },
            picked_at: pick.picked_at |> DateTime.to_iso8601(),
            pick_duration_ms: pick.pick_duration_ms
          }
        end) |> Enum.sort_by(& &1.pick_number),
        roster_count: length(team_picks),
        roster_complete: length(team_picks) == picks_per_team
      }
    end)
    |> Enum.sort_by(& &1.pick_order_position)

    total_picks_possible = length(draft.teams) * picks_per_team

    %{
      draft: %{
        id: draft.id,
        name: draft.name,
        status: draft.status,
        format: draft.format,
        captains_required: draft.captains_required,
        picks_per_team: picks_per_team,
        total_teams: length(draft.teams),
        total_picks_possible: total_picks_possible,
        total_picks_made: Drafts.count_picks(draft.id)
      },
      teams: teams_with_rosters,
      draft_progress: %{
        completed_picks: Drafts.count_picks(draft.id),
        total_picks: total_picks_possible,
        percentage: if(total_picks_possible > 0, do: round((Drafts.count_picks(draft.id) / total_picks_possible) * 100), else: 0),
        teams_complete: Enum.count(teams_with_rosters, & &1.roster_complete),
        teams_incomplete: Enum.count(teams_with_rosters, &(!&1.roster_complete))
      },
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp build_available_players_data(draft) do
    # Get all available players (not yet picked)
    available_players = Drafts.list_available_players(draft.id) || []
    
    # Group players by their primary role (first in preferred_roles list)
    players_by_role = Enum.group_by(available_players, fn player ->
      case player.preferred_roles do
        [first_role | _] -> normalize_role(first_role)
        [] -> "unassigned"
      end
    end)
    
    # Define role order and get counts
    role_order = ["top", "jungle", "mid", "adc", "support", "unassigned"]
    
    role_groups = Enum.map(role_order, fn role ->
      players = Map.get(players_by_role, role, [])
      
      %{
        role: role,
        role_display: format_role_display(role),
        count: length(players),
        players: Enum.map(players, fn player ->
          %{
            id: player.id,
            display_name: player.display_name,
            preferred_roles: player.preferred_roles,
            custom_stats: player.custom_stats,
            organizer_notes: player.organizer_notes
          }
        end) |> Enum.sort_by(& &1.display_name)
      }
    end)
    
    %{
      draft: %{
        id: draft.id,
        name: draft.name,
        status: draft.status,
        total_players: length(available_players) + Drafts.count_picks(draft.id),
        available_players: length(available_players),
        picked_players: Drafts.count_picks(draft.id)
      },
      role_groups: role_groups,
      total_available: length(available_players),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end
  
  defp normalize_role(role) do
    role_string = case role do
      atom when is_atom(atom) -> Atom.to_string(atom)
      string when is_binary(string) -> string
      _ -> to_string(role)
    end
    
    case String.downcase(String.trim(role_string)) do
      "top" -> "top"
      "jungle" -> "jungle"
      "jg" -> "jungle"
      "mid" -> "mid"
      "middle" -> "mid"
      "adc" -> "adc"
      "bot" -> "adc"
      "bottom" -> "adc"
      "support" -> "support"
      "utility" -> "support"
      "supp" -> "support"
      _ -> "unassigned"
    end
  end
  
  defp format_role_display(role) do
    case role do
      "top" -> "Top Lane"
      "jungle" -> "Jungle"
      "mid" -> "Mid Lane"
      "adc" -> "ADC/Bot"
      "support" -> "Support"
      "unassigned" -> "No Role"
    end
  end

  defp get_current_team(draft) do
    if draft.status == :active do
      Drafts.get_next_team_to_pick(draft)
    else
      nil
    end
  end

  defp format_team_for_stream(team) do
    %{
      id: team.id,
      name: team.name,
      logo_url: team.logo_url,
      pick_order_position: team.pick_order_position,
      color: get_team_color(team.pick_order_position),
      is_ready: team.is_ready
    }
  end

  defp format_pick_for_stream(pick) do
    pick = Drafts.preload_pick_associations(pick)
    
    # Ensure player has champion loaded
    player_with_champion = AceApp.Repo.preload(pick.player, [:champion])
    
    # Always use player's assigned champion for consistency (not pick's champion)
    champion_data = if player_with_champion.champion do
      # Use player's preferred skin if specified, otherwise random
      skin_data = if player_with_champion.preferred_skin_id do
        skin = AceApp.LoL.get_champion_skin(player_with_champion.champion.id, player_with_champion.preferred_skin_id)
        if skin do
          splash_url = AceApp.LoL.get_skin_splash_url(player_with_champion.champion, skin)
          %{
            splash_url: splash_url,
            skin_name: if(skin.skin_id != 0, do: skin.name, else: nil)
          }
        else
          AceApp.LoL.get_random_champion_skin_with_url(player_with_champion.champion)
        end
      else
        AceApp.LoL.get_random_champion_skin_with_url(player_with_champion.champion)
      end
      
      %{
        id: player_with_champion.champion.id,
        name: player_with_champion.champion.name,
        title: player_with_champion.champion.title,
        image_url: player_with_champion.champion.image_url,
        splash_url: skin_data.splash_url,
        skin_name: skin_data.skin_name
      }
    else
      nil
    end
    
    %{
      pick_number: pick.pick_number,
      round_number: pick.round_number,
      team: %{
        name: pick.team.name,
        logo_url: pick.team.logo_url,
        color: get_team_color(pick.team.pick_order_position)
      },
      player: %{
        name: pick.player.display_name,
        roles: pick.player.preferred_roles
      },
      champion: champion_data,
      picked_at: pick.picked_at |> DateTime.to_iso8601()
    }
  end

  defp format_pick_for_timeline(pick) do
    pick = Drafts.preload_pick_associations(pick)
    
    %{
      pick_number: pick.pick_number,
      team_name: pick.team.name,
      player_name: pick.player.display_name,
      team_color: get_team_color(pick.team.pick_order_position),
      time_ago: time_ago_in_words(pick.picked_at)
    }
  end

  defp format_current_turn(team, draft) do
    picks_count = Drafts.count_picks(draft.id)
    
    %{
      team: %{
        id: team.id,
        name: team.name,
        logo_url: team.logo_url,
        color: get_team_color(team.pick_order_position)
      },
      pick_number: picks_count + 1,
      round: div(picks_count, length(draft.teams)) + 1
    }
  end

  defp format_timer_data(draft) do
    case draft.timer_status do
      "running" ->
        remaining = draft.timer_remaining_seconds || 0
        %{
          active: true,
          remaining_seconds: max(remaining, 0),
          total_seconds: draft.pick_timer_seconds,
          percentage: if(draft.pick_timer_seconds > 0, do: round((remaining / draft.pick_timer_seconds) * 100), else: 0)
        }
      _ ->
        %{
          active: false,
          remaining_seconds: 0,
          total_seconds: draft.pick_timer_seconds,
          percentage: 0
        }
    end
  end

  defp get_team_color(position) do
    case position do
      1 -> "blue"
      2 -> "red"
      3 -> "green"
      4 -> "purple"
      5 -> "orange"
      6 -> "pink"
      7 -> "indigo"
      8 -> "cyan"
      9 -> "amber"
      10 -> "emerald"
      _ -> "gray"
    end
  end

  defp time_ago_in_words(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)
    
    cond do
      diff < 60 -> "#{diff}s ago"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      true -> "#{div(diff, 86400)}d ago"
    end
  end
end