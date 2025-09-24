defmodule Mix.Tasks.BackfillChampions do
  @moduledoc """
  Backfills random champions for all drafts that have players without champions.
  
  This task is useful for updating existing drafts that were created before
  automatic champion assignment was implemented.
  
  ## Usage
  
      mix backfill_champions
  
  This will assign random champions to all players who don't currently have
  champions assigned across all drafts.
  """
  
  use Mix.Task
  import Ecto.Query

  @requirements ["app.start"]

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("Starting champion and skin backfill for all drafts...")
    
    # First, backfill champions for players without any champion
    champion_result = AceApp.Drafts.backfill_random_champions_for_all_drafts()
    
    Mix.shell().info("Champion backfill complete!")
    Mix.shell().info("📊 Champion Results:")
    Mix.shell().info("  • Drafts updated: #{champion_result.drafts_updated}")
    Mix.shell().info("  • Drafts failed: #{champion_result.drafts_failed}")
    Mix.shell().info("  • Total players assigned champions: #{champion_result.total_players_assigned}")
    
    # Now backfill skins for players who have champions but no skins
    Mix.shell().info("Starting skin backfill for players with champions...")
    
    # Get all draft IDs and backfill skins
    all_draft_ids = from(d in AceApp.Drafts.Draft, select: d.id) |> AceApp.Repo.all()
    
    skin_results = Enum.map(all_draft_ids, fn draft_id ->
      case AceApp.Drafts.assign_random_skins_to_players(draft_id) do
        {:ok, count} -> {:ok, draft_id, count}
        {:error, reason} -> {:error, draft_id, reason}
      end
    end)
    
    successful_skin_assignments = Enum.filter(skin_results, fn 
      {:ok, _, _} -> true
      _ -> false
    end)
    
    total_skins_assigned = successful_skin_assignments 
    |> Enum.map(fn {:ok, _, count} -> count end)
    |> Enum.sum()
    
    Mix.shell().info("Skin backfill complete!")
    Mix.shell().info("📊 Skin Results:")
    Mix.shell().info("  • Total players assigned skins: #{total_skins_assigned}")
    
    if champion_result.drafts_failed > 0 do
      Mix.shell().info("⚠️  Some champion assignments failed:")
      Enum.each(champion_result.results, fn
        {:error, draft_id, reason} ->
          Mix.shell().info("  • Draft #{draft_id}: #{inspect(reason)}")
        _ -> nil
      end)
    end
    
    total_updates = champion_result.total_players_assigned + total_skins_assigned
    
    if total_updates > 0 do
      Mix.shell().info("✅ Backfill successful!")
      Mix.shell().info("📈 Total Summary:")
      Mix.shell().info("  • #{champion_result.total_players_assigned} players got champions")
      Mix.shell().info("  • #{total_skins_assigned} players got consistent skins")
      Mix.shell().info("  • #{total_updates} total assignments made")
    else
      Mix.shell().info("ℹ️  No players needed champion or skin assignment.")
    end
  end
end