defmodule AceApp.Imports do
  @moduledoc """
  The Imports context for managing CSV import operations.
  """

  import Ecto.Query, warn: false
  alias AceApp.Repo
  alias AceApp.Imports.ImportJob
  alias AceApp.Drafts
  alias AceApp.Files
  alias AceApp.LoL

  require Logger

  @doc """
  Creates an import job for the given draft and file upload.
  """
  def create_import_job(attrs \\ %{}) do
    %ImportJob{}
    |> ImportJob.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a single import job.
  """
  def get_import_job!(id), do: Repo.get!(ImportJob, id)

  @doc """
  Gets a single import job.
  """
  def get_import_job(id), do: Repo.get(ImportJob, id)

  @doc """
  Updates an import job.
  """
  def update_import_job(%ImportJob{} = import_job, attrs) do
    import_job
    |> ImportJob.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Lists all import jobs for a draft.
  """
  def list_import_jobs(draft_id) do
    ImportJob
    |> where([ij], ij.draft_id == ^draft_id)
    |> order_by([ij], desc: ij.inserted_at)
    |> Repo.all()
  end

  @doc """
  Starts a CSV import process from a file upload.
  """
  def start_csv_import(draft_id, file_upload_id, import_type, imported_by \\ "organizer") do
    with {:ok, file_upload} <- Files.get_file_upload(file_upload_id),
         {:ok, csv_data} <- parse_csv_file(file_upload.file_path),
         {:ok, import_job} <- create_import_job(%{
           draft_id: draft_id,
           file_upload_id: file_upload_id,
           import_type: import_type,
           status: "pending",
           total_records: length(csv_data),
           import_data: %{"csv_rows" => csv_data},
           imported_by: imported_by
         }) do
      # Start async processing
      Task.start(fn -> process_import_job(import_job.id) end)
      {:ok, import_job}
    else
      error -> error
    end
  end

  @doc """
  Starts a CSV import process from raw CSV content.
  """
  def start_csv_import_from_content(draft_id, csv_content, import_type, imported_by \\ "organizer") do
    with {:ok, csv_data} <- parse_csv_content(csv_content),
         {:ok, import_job} <- create_import_job(%{
           draft_id: draft_id,
           import_type: import_type,
           status: "pending",
           total_records: length(csv_data),
           import_data: %{"csv_rows" => csv_data},
           imported_by: imported_by
         }) do
      # Start async processing
      Task.start(fn -> process_import_job(import_job.id) end)
      {:ok, import_job}
    else
      error -> error
    end
  end

  @doc """
  Validates CSV data without importing.
  """
  def validate_csv_import(draft_id, csv_content, import_type) do
    with {:ok, csv_data} <- parse_csv_content(csv_content) do
      case import_type do
        "players" -> validate_players_csv(draft_id, csv_data)
        "teams" -> validate_teams_csv(draft_id, csv_data)
        _ -> {:error, "Invalid import type"}
      end
    end
  end

  # Private functions

  defp parse_csv_file(file_path) do
    case File.read(file_path) do
      {:ok, content} -> parse_csv_content(content)
      {:error, reason} -> {:error, "Failed to read file: #{reason}"}
    end
  end

  defp parse_csv_content(content) do
    try do
      csv_data = 
        content
        |> NimbleCSV.RFC4180.parse_string(skip_headers: false)
        |> Enum.map(fn row -> Enum.map(row, &String.trim/1) end)

      case csv_data do
        [] -> {:error, "CSV file is empty"}
        [_headers | []] -> {:error, "CSV file has no data rows"}
        [headers | rows] -> {:ok, %{"headers" => headers, "rows" => rows}}
        _ -> {:error, "Invalid CSV format"}
      end
    rescue
      error -> {:error, "Failed to parse CSV: #{inspect(error)}"}
    end
  end

  defp process_import_job(import_job_id) do
    import_job = get_import_job!(import_job_id)
    
    # Update status to processing
    {:ok, import_job} = update_import_job(import_job, %{
      status: "processing",
      started_at: DateTime.utc_now()
    })

    case import_job.import_type do
      "players" -> process_players_import(import_job)
      "teams" -> process_teams_import(import_job)
      _ -> 
        update_import_job(import_job, %{
          status: "failed",
          processing_errors: %{"general" => "Invalid import type"},
          completed_at: DateTime.utc_now()
        })
    end
  end

  defp process_players_import(import_job) do
    csv_data = import_job.import_data["csv_rows"]
    headers = csv_data["headers"]
    rows = csv_data["rows"]

    {successful, failed, errors} = process_player_rows(import_job.draft_id, headers, rows)

    update_import_job(import_job, %{
      status: if(failed == 0, do: "completed", else: "completed_with_errors"),
      successful_records: successful,
      failed_records: failed,
      processed_records: successful + failed,
      validation_errors: errors,
      completed_at: DateTime.utc_now()
    })
  end

  defp process_teams_import(import_job) do
    csv_data = import_job.import_data["csv_rows"]
    headers = csv_data["headers"]
    rows = csv_data["rows"]

    {successful, failed, errors} = process_team_rows(import_job.draft_id, headers, rows)

    update_import_job(import_job, %{
      status: if(failed == 0, do: "completed", else: "completed_with_errors"),
      successful_records: successful,
      failed_records: failed,
      processed_records: successful + failed,
      validation_errors: errors,
      completed_at: DateTime.utc_now()
    })
  end

  defp process_player_rows(draft_id, headers, rows) do
    # Map headers to expected fields
    header_map = map_player_headers(headers)
    
    {successful, failed, errors} = 
      rows
      |> Enum.with_index(1)
      |> Enum.reduce({0, 0, %{}}, fn {row, row_num}, {succ, fail, errs} ->
        case create_player_from_row(draft_id, header_map, row) do
          {:ok, _player} -> {succ + 1, fail, errs}
          {:error, error} -> {succ, fail + 1, Map.put(errs, "row_#{row_num}", error)}
        end
      end)

    {successful, failed, errors}
  end

  defp process_team_rows(draft_id, headers, rows) do
    # Map headers to expected fields
    header_map = map_team_headers(headers)
    
    {successful, failed, errors} = 
      rows
      |> Enum.with_index(1)
      |> Enum.reduce({0, 0, %{}}, fn {row, row_num}, {succ, fail, errs} ->
        case create_team_from_row(draft_id, header_map, row) do
          {:ok, _team} -> {succ + 1, fail, errs}
          {:error, error} -> {succ, fail + 1, Map.put(errs, "row_#{row_num}", error)}
        end
      end)

    {successful, failed, errors}
  end

  defp map_player_headers(headers) do
    Enum.with_index(headers)
    |> Enum.reduce(%{}, fn {header, index}, acc ->
      normalized_header = header |> String.downcase() |> String.trim()
      
      field = case normalized_header do
        h when h in ["name", "display_name", "player_name", "displayname"] -> :display_name
        h when h in ["roles", "preferred_roles", "role", "position"] -> :preferred_roles
        h when h in ["summoner", "summoner_name", "ign", "username"] -> :summoner_name
        h when h in ["rank", "tier", "rank_tier"] -> :rank_tier
        h when h in ["division", "rank_division"] -> :rank_division
        h when h in ["server", "region", "server_region"] -> :server_region
        h when h in ["notes", "organizer_notes", "custom_stats"] -> :organizer_notes
        h when h in ["champion", "champion_name", "championname", "champ"] -> :champion_name
        h when h in ["skin", "skin_name", "skinname"] -> :skin_name
        _ -> nil
      end
      
      if field, do: Map.put(acc, field, index), else: acc
    end)
  end

  defp map_team_headers(headers) do
    Enum.with_index(headers)
    |> Enum.reduce(%{}, fn {header, index}, acc ->
      normalized_header = header |> String.downcase() |> String.trim()
      
      field = case normalized_header do
        h when h in ["name", "team_name", "teamname"] -> :name
        h when h in ["logo", "logo_url", "logourl", "image", "image_url"] -> :logo_url
        h when h in ["order", "pick_order", "position", "pick_position"] -> :pick_order_position
        _ -> nil
      end
      
      if field, do: Map.put(acc, field, index), else: acc
    end)
  end

  defp create_player_from_row(draft_id, header_map, row) do
    # Extract required field
    display_name = get_cell_value(row, header_map[:display_name])
    
    if is_nil(display_name) or String.trim(display_name) == "" do
      {:error, "Display name is required"}
    else
      # Extract optional fields
      preferred_roles = parse_roles(get_cell_value(row, header_map[:preferred_roles]))
      organizer_notes = get_cell_value(row, header_map[:organizer_notes])
      
      # Parse champion and skin
      champion_name = get_cell_value(row, header_map[:champion_name])
      skin_name = get_cell_value(row, header_map[:skin_name])
      {champion_id, skin_id, champion_warnings} = parse_champion_and_skin(champion_name, skin_name)
      
      # Build player attributes
      player_attrs = %{
        draft_id: draft_id,
        display_name: String.trim(display_name),
        preferred_roles: preferred_roles,
        organizer_notes: organizer_notes,
        champion_id: champion_id,
        skin_id: skin_id
      }
      
      # Add warnings to organizer notes if there are champion/skin parsing issues
      player_attrs = if length(champion_warnings) > 0 do
        warning_text = "⚠️ Champion/Skin: " <> Enum.join(champion_warnings, "; ")
        existing_notes = player_attrs[:organizer_notes] || ""
        updated_notes = if String.trim(existing_notes) == "" do
          warning_text
        else
          existing_notes <> " | " <> warning_text
        end
        Map.put(player_attrs, :organizer_notes, updated_notes)
      else
        player_attrs
      end

      case Drafts.create_player(player_attrs) do
        {:ok, player} ->
          # Create account if summoner info provided
          create_player_account_if_present(player, header_map, row)
          {:ok, player}
        {:error, changeset} ->
          {:error, format_changeset_errors(changeset)}
      end
    end
  end

  defp create_team_from_row(draft_id, header_map, row) do
    # Extract required field
    name = get_cell_value(row, header_map[:name])
    
    if is_nil(name) or String.trim(name) == "" do
      {:error, "Team name is required"}
    else
      # Extract optional fields
      logo_url = get_cell_value(row, header_map[:logo_url])
      pick_order = parse_integer(get_cell_value(row, header_map[:pick_order_position]))
      
      # Build team attributes
      team_attrs = %{
        name: String.trim(name),
        logo_url: if(logo_url && String.trim(logo_url) != "", do: String.trim(logo_url), else: nil),
        pick_order_position: pick_order
      }

      case Drafts.create_team(draft_id, team_attrs) do
        {:ok, team} -> {:ok, team}
        {:error, changeset} -> {:error, format_changeset_errors(changeset)}
      end
    end
  end

  defp create_player_account_if_present(player, header_map, row) do
    summoner_name = get_cell_value(row, header_map[:summoner_name])
    rank_tier = get_cell_value(row, header_map[:rank_tier])
    rank_division = get_cell_value(row, header_map[:rank_division])
    server_region = get_cell_value(row, header_map[:server_region])

    if summoner_name && String.trim(summoner_name) != "" do
      account_attrs = %{
        player_id: player.id,
        summoner_name: String.trim(summoner_name),
        rank_tier: rank_tier,
        rank_division: rank_division,
        server_region: server_region || "NA1",
        is_primary: true
      }

      Drafts.create_player_account(account_attrs)
    end
  end

  defp get_cell_value(_row, nil), do: nil
  defp get_cell_value(row, index) when is_integer(index) and index < length(row) do
    Enum.at(row, index)
  end
  defp get_cell_value(_row, _index), do: nil

  defp parse_roles(nil), do: []
  defp parse_roles(""), do: []
  defp parse_roles(roles_str) do
    roles_str
    |> String.split([",", ";", "|", " "], trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.downcase/1)
    |> Enum.filter(fn role -> role in ["top", "jungle", "mid", "adc", "support"] end)
  end

  defp parse_integer(nil), do: nil
  defp parse_integer(""), do: nil
  defp parse_integer(str) when is_binary(str) do
    case Integer.parse(str) do
      {int, _} -> int
      :error -> nil
    end
  end
  defp parse_integer(int) when is_integer(int), do: int

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map(fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
    |> Enum.join("; ")
  end

  defp parse_champion_and_skin(champion_name, skin_name) do
    champion_id = find_champion_by_name(champion_name)
    {skin_id, skin_warnings} = find_skin_by_name(champion_id, skin_name)
    
    warnings = []
    warnings = if champion_name && String.trim(champion_name) != "" && is_nil(champion_id) do
      ["Champion '#{champion_name}' not found" | warnings]
    else
      warnings
    end
    
    warnings = warnings ++ skin_warnings
    
    {champion_id, skin_id, warnings}
  end

  defp find_champion_by_name(nil), do: nil
  defp find_champion_by_name(""), do: nil
  defp find_champion_by_name(name) when is_binary(name) do
    normalized_name = String.downcase(String.trim(name))
    
    champions = LoL.list_enabled_champions()
    
    # Try exact match first
    exact_match = Enum.find(champions, fn champion ->
      String.downcase(champion.name) == normalized_name
    end)
    
    if exact_match do
      exact_match.id
    else
      # Try fuzzy matching - remove spaces, apostrophes, and common variations
      fuzzy_name = normalized_name
        |> String.replace(~r/['\s\-\.]/, "")
        |> String.replace("&", "and")
      
      fuzzy_match = Enum.find(champions, fn champion ->
        fuzzy_champion_name = champion.name
          |> String.downcase()
          |> String.replace(~r/['\s\-\.]/, "")
          |> String.replace("&", "and")
        
        fuzzy_champion_name == fuzzy_name or
        String.contains?(fuzzy_champion_name, fuzzy_name) or
        String.contains?(fuzzy_name, fuzzy_champion_name)
      end)
      
      if fuzzy_match, do: fuzzy_match.id, else: nil
    end
  end

  defp find_skin_by_name(nil, _skin_name), do: {nil, []}
  defp find_skin_by_name(_champion_id, nil), do: {nil, []}
  defp find_skin_by_name(_champion_id, ""), do: {nil, []}
  defp find_skin_by_name(champion_id, skin_name) when is_binary(skin_name) do
    normalized_skin = String.downcase(String.trim(skin_name))
    
    skins = LoL.list_champion_skins(champion_id)
    
    # Try exact match first
    exact_match = Enum.find(skins, fn skin ->
      String.downcase(skin.name) == normalized_skin
    end)
    
    if exact_match do
      {exact_match.id, []}
    else
      # Try fuzzy matching
      fuzzy_skin = normalized_skin
        |> String.replace(~r/['\s\-\.]/, "")
        |> String.replace("&", "and")
      
      fuzzy_match = Enum.find(skins, fn skin ->
        fuzzy_skin_name = skin.name
          |> String.downcase()
          |> String.replace(~r/['\s\-\.]/, "")
          |> String.replace("&", "and")
        
        fuzzy_skin_name == fuzzy_skin or
        String.contains?(fuzzy_skin_name, fuzzy_skin) or
        String.contains?(fuzzy_skin, fuzzy_skin_name)
      end)
      
      if fuzzy_match do
        {fuzzy_match.id, []}
      else
        {nil, ["Skin '#{skin_name}' not found for champion"]}
      end
    end
  end

  defp validate_players_csv(_draft_id, _csv_data) do
    # TODO: Implement validation without creating records
    {:ok, %{valid: true, errors: []}}
  end

  defp validate_teams_csv(_draft_id, _csv_data) do
    # TODO: Implement validation without creating records
    {:ok, %{valid: true, errors: []}}
  end
end