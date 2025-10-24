defmodule AceAppWeb.DraftSetupLive do
  use AceAppWeb, :live_view

  alias AceApp.{Drafts, Imports}
  alias AceApp.LoL

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Create Draft")
     |> assign(:step, :basic_info)
     |> assign(:draft, nil)
     |> assign(:changeset, Drafts.change_draft(%Drafts.Draft{}))
     |> assign(:selected_format, :snake)
     |> assign(:teams, [])
     |> assign(:players, [])
     # Lazy-loaded when needed
     |> assign(:champions, [])
     # Will be populated when champion is selected
     |> assign(:champion_skins, [])
     |> assign(:errors, [])
     # :teams, :players, or nil
     |> assign(:csv_import_step, nil)
     |> assign(:csv_preview_data, [])
     |> assign(:csv_validation_errors, [])
     # team being edited
     |> assign(:editing_team, nil)
     # player being edited
     |> assign(:editing_player, nil)
     # for editing existing teams
     |> assign(:team_changeset, nil)
     # for adding new teams
     |> assign(:new_team_changeset, Drafts.change_team(%Drafts.Team{}))
     |> assign(:player_changeset, nil)
     # for captain team selection modal
     |> assign(:captain_player_id, nil)
     |> allow_upload(:team_logo,
       accept: ~w(.png .jpg .jpeg .svg .webp),
       max_entries: 1,
       max_file_size: 10_485_760,
       auto_upload: true,
       progress: &handle_logo_progress/3
     )
     |> allow_upload(:csv_file,
       accept: ~w(.csv),
       max_entries: 1,
       # 5MB
       max_file_size: 5_242_880,
       auto_upload: true
     )}
  end

  @impl true
  def handle_params(%{"draft_id" => draft_id}, _uri, socket) do
    try do
      draft = Drafts.get_draft!(draft_id)
      teams = Drafts.list_teams(draft.id)
      players = Drafts.list_players(draft.id)
      changeset = Drafts.change_draft(draft)

      # Determine the appropriate step based on current state
      # For newly created drafts with setup status, always start at basic_info
      step =
        cond do
          # New draft
          draft.status == :setup and length(teams) == 0 and length(players) == 0 -> :basic_info
          # Ready to finalize
          length(players) >= length(teams) * 5 -> :players
          # Has teams, need players
          length(teams) >= 2 -> :players
          # Has some teams, stay on teams
          length(teams) > 0 -> :teams
          # Fallback to basic info
          true -> :basic_info
        end

      # Load champions if we're on the players step
      champions =
        if step == :players do
          LoL.list_enabled_champions()
        else
          []
        end

      {:noreply,
       socket
       |> assign(:page_title, "Edit Draft - #{draft.name}")
       |> assign(:step, step)
       |> assign(:draft, draft)
       |> assign(:changeset, changeset)
       |> assign(:selected_format, draft.format)
       |> assign(:teams, teams)
       |> assign(:players, players)
       |> assign(:champions, champions)
       |> allow_upload(:team_logo,
         accept: ~w(.png .jpg .jpeg .svg .webp),
         max_entries: 1,
         max_file_size: 10_485_760,
         auto_upload: true,
         progress: &handle_logo_progress/3
       )}
    rescue
      Ecto.NoResultsError ->
        {:noreply,
         socket
         |> put_flash(:error, "Draft not found")
         |> push_navigate(to: "/drafts/new")}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"draft" => draft_params}, socket) do
    changeset =
      %Drafts.Draft{}
      |> Drafts.change_draft(draft_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("create_draft", %{"draft" => draft_params}, socket) do
    case Drafts.create_draft(draft_params) do
      {:ok, draft} ->
        # Validate Discord webhook if provided
        draft = maybe_validate_discord_webhook(draft, draft_params)

        # Send message to refresh sidebar navigation
        send_update(AceAppWeb.Components.SidebarNav, id: "sidebar-nav", refresh: true)

        {:noreply,
         socket
         |> put_flash(:info, "Draft created successfully!")
         |> push_navigate(to: "/drafts/#{draft.id}/setup")}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def handle_event("format_changed", %{"draft" => %{"format" => format}}, socket) do
    format_atom = String.to_existing_atom(format)
    {:noreply, assign(socket, :selected_format, format_atom)}
  end

  @impl true
  def handle_event("update_draft", %{"draft" => draft_params}, socket) do
    case Drafts.update_draft(socket.assigns.draft, draft_params) do
      {:ok, draft} ->
        # Validate Discord webhook if provided
        draft = maybe_validate_discord_webhook(draft, draft_params)

        {:noreply,
         socket
         |> assign(:draft, draft)
         |> assign(:changeset, Drafts.change_draft(draft))
         |> assign(:selected_format, draft.format)
         |> put_flash(:info, "Draft updated successfully!")}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def handle_event("next_step", _params, socket) do
    next_step = get_next_step(socket.assigns.step)
    {:noreply, assign(socket, :step, next_step)}
  end

  @impl true
  def handle_event("goto_step", %{"step" => step}, socket) do
    step_atom = String.to_existing_atom(step)

    socket =
      case step_atom do
        :players ->
          # Load champions only when needed for players step
          if socket.assigns.champions == [] do
            champions = LoL.list_enabled_champions()
            assign(socket, :champions, champions)
          else
            socket
          end

        _ ->
          socket
      end

    {:noreply, assign(socket, :step, step_atom)}
  end

  @impl true
  def handle_event("start_csv_import", %{"type" => type}, socket) do
    {:noreply, assign(socket, :csv_import_step, String.to_existing_atom(type))}
  end

  @impl true
  def handle_event("validate_csv_file", _params, socket) do
    # This is called when file is selected - check if we can process it
    IO.puts("validate_csv_file called, entries: #{length(socket.assigns.uploads.csv_file.entries)}")
    
    # Check if file is uploaded and ready to process
    uploaded_entries = socket.assigns.uploads.csv_file.entries
    
    case uploaded_entries do
      [entry | _] when entry.done? ->
        IO.puts("Entry is done, processing now!")
        # File is ready, process it immediately
        process_csv_import(socket)
      
      [entry | _] ->
        IO.puts("Entry not done yet: progress=#{entry.progress}, done=#{entry.done?}")
        # Schedule a check in 100ms to see if it's done
        Process.send_after(self(), :check_csv_upload, 100)
        {:noreply, socket}
      
      [] ->
        IO.puts("No entries yet")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:check_csv_upload, socket) do
    IO.puts("Checking CSV upload status...")
    uploaded_entries = socket.assigns.uploads.csv_file.entries
    
    case uploaded_entries do
      [entry | _] when entry.done? ->
        IO.puts("Entry is now done! Processing...")
        # File is ready, process it
        process_csv_import(socket)
      
      [entry | _] ->
        IO.puts("Still uploading: progress=#{entry.progress}")
        # Schedule another check
        Process.send_after(self(), :check_csv_upload, 100)
        {:noreply, socket}
      
      [] ->
        IO.puts("No entries found")
        {:noreply, socket}
    end
  end

  defp process_csv_import(socket) do
    IO.puts("process_csv_import called")
    case consume_uploaded_entries(socket, :csv_file, &process_csv_upload/2) do
      [csv_content] ->
        import_type =
          case socket.assigns.csv_import_step do
            :teams -> "teams"
            :players -> "players"
          end

        case parse_csv_data(csv_content) do
          {:ok, [_ | _] = parsed_data} ->
            # Use the cleaned CSV content for validation
            cleaned_content =
              csv_content
              |> String.replace("\r\n", "\n")
              |> String.replace("\r", "\n")
              |> clean_csv_quotes()

            case Imports.validate_csv_import(
                   socket.assigns.draft.id,
                   cleaned_content,
                   import_type
                 ) do
              {:ok, _validation_results} ->
                # Auto-import immediately after validation
                socket_with_data =
                  socket
                  |> assign(:csv_preview_data, parsed_data)
                  |> assign(:csv_validation_errors, [])

                # Trigger the import based on type
                case socket.assigns.csv_import_step do
                  :teams -> import_teams_from_csv(socket_with_data)
                  :players -> import_players_from_csv(socket_with_data)
                end

              {:error, errors} when is_list(errors) ->
                {:noreply,
                 socket
                 |> assign(:csv_preview_data, parsed_data)
                 |> assign(:csv_validation_errors, errors)
                 |> put_flash(:error, "CSV has validation errors. Please review.")}

              {:error, error} ->
                {:noreply,
                 socket
                 |> put_flash(:error, "Validation failed: #{format_error_message(error)}")}
            end

          {:ok, _empty_data} ->
            {:noreply,
             socket
             |> put_flash(:error, "CSV file appears to be empty or contains no valid data rows.")}

          {:error, error} ->
            {:noreply,
             socket
             |> put_flash(:error, "Invalid CSV file format: #{format_error_message(error)}")}
        end

      [] ->
        IO.puts("No uploaded entries to consume")
        {:noreply, socket}

      _other ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to process the uploaded file. Please try again.")}
    end
  rescue
    error ->
      IO.inspect(error, label: "Error in process_csv_import")
      {:noreply,
       socket
       |> put_flash(
         :error,
         "An error occurred while processing your CSV file. Please check the file format and try again."
       )}
  end

  @impl true
  def handle_event("cancel_csv_import", _params, socket) do
    {:noreply,
     socket
     |> assign(:csv_import_step, nil)
     |> assign(:csv_preview_data, [])
     |> assign(:csv_validation_errors, [])}
  end

  # CSV upload handlers moved to handle_csv_progress/2 for auto-upload

  @impl true
  def handle_event("import_csv_data", _params, socket) do
    case socket.assigns.csv_import_step do
      :teams ->
        import_teams_from_csv(socket)

      :players ->
        import_players_from_csv(socket)

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid import step")}
    end
  end

  @impl true
  def handle_event("edit_team", %{"team-id" => team_id}, socket) do
    team_id = String.to_integer(team_id)
    team = Enum.find(socket.assigns.teams, &(&1.id == team_id))

    if team do
      changeset = Drafts.change_team(team, %{})

      {:noreply,
       socket
       |> assign(:editing_team, team)
       |> assign(:team_changeset, changeset)}
    else
      {:noreply, put_flash(socket, :error, "Team not found")}
    end
  end

  @impl true
  def handle_event("cancel_edit_team", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_team, nil)
     |> assign(:team_changeset, nil)}
  end

  @impl true
  def handle_event("validate_team_edit", %{"team" => team_params}, socket) do
    changeset =
      socket.assigns.editing_team
      |> Drafts.change_team(team_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :team_changeset, changeset)}
  end

  @impl true
  def handle_event("update_team", %{"team" => team_params}, socket) do
    # Handle file upload if present
    {team_params, uploaded_files} = handle_team_logo_upload(socket, team_params)

    case Drafts.update_team(socket.assigns.editing_team, team_params) do
      {:ok, _team} ->
        # Process uploaded files
        process_team_logo_files(socket.assigns.editing_team, uploaded_files)

        teams = Drafts.list_teams(socket.assigns.draft.id)

        {:noreply,
         socket
         |> assign(:teams, teams)
         |> assign(:editing_team, nil)
         |> assign(:team_changeset, nil)
         |> put_flash(:info, "Team updated successfully!")}

      {:error, changeset} ->
        {:noreply, assign(socket, :team_changeset, changeset)}
    end
  end

  @impl true
  def handle_event("edit_player", %{"player-id" => player_id}, socket) do
    player_id = String.to_integer(player_id)
    # Get player with champion association
    player = AceApp.Repo.get(Drafts.Player, player_id) |> AceApp.Repo.preload([:champion])

    if player do
      changeset = Drafts.change_player(player, %{})

      # Load champions if not already loaded (needed for edit modal)
      socket =
        if socket.assigns.champions == [] do
          champions = LoL.list_enabled_champions()
          assign(socket, :champions, champions)
        else
          socket
        end

      # Load skins if player has a champion assigned
      champion_skins =
        if player.champion_id do
          LoL.list_champion_skins(player.champion_id)
        else
          []
        end

      {:noreply,
       socket
       |> assign(:editing_player, player)
       |> assign(:player_changeset, changeset)
       |> assign(:champion_skins, champion_skins)}
    else
      {:noreply, put_flash(socket, :error, "Player not found")}
    end
  end

  @impl true
  def handle_event("cancel_edit_player", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_player, nil)
     |> assign(:player_changeset, nil)}
  end

  def handle_event("ignore", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate_player_edit", %{"player" => player_params}, socket) do
    changeset =
      socket.assigns.editing_player
      |> Drafts.change_player(player_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :player_changeset, changeset)}
  end

  @impl true
  def handle_event("update_player", %{"player" => player_params}, socket) do
    case Drafts.update_player(socket.assigns.editing_player, player_params) do
      {:ok, _player} ->
        players = Drafts.list_players(socket.assigns.draft.id)

        {:noreply,
         socket
         |> assign(:players, players)
         |> assign(:editing_player, nil)
         |> assign(:player_changeset, nil)
         |> put_flash(:info, "Player updated successfully!")}

      {:error, changeset} ->
        {:noreply, assign(socket, :player_changeset, changeset)}
    end
  end

  @impl true
  def handle_event("download_csv_template", %{"type" => type}, socket) do
    template_content = generate_csv_template(type)

    {:noreply,
     socket
     |> push_event("download_csv", %{
       content: template_content,
       filename: "#{type}_import_template.csv"
     })}
  end

  @impl true
  def handle_event("prev_step", _params, socket) do
    prev_step = get_prev_step(socket.assigns.step)
    {:noreply, assign(socket, :step, prev_step)}
  end

  @impl true
  def handle_event("validate_new_team", %{"team" => team_params}, socket) do
    changeset =
      %Drafts.Team{}
      |> Drafts.change_team(team_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :new_team_changeset, changeset)}
  end

  @impl true
  def handle_event("add_team", %{"team" => team_params}, socket) do
    draft = socket.assigns.draft

    # Handle file upload if present
    {team_params, uploaded_files} = handle_team_logo_upload(socket, team_params)

    case Drafts.create_team(draft.id, team_params) do
      {:ok, team} ->
        # Process uploaded files
        process_team_logo_files(team, uploaded_files)

        teams = Drafts.list_teams(draft.id)

        {:noreply,
         socket
         |> assign(:teams, teams)
         # Reset form
         |> assign(:new_team_changeset, Drafts.change_team(%Drafts.Team{}))
         |> push_event("clear-form", %{form: "team-form"})
         |> put_flash(:info, "Team added successfully!")}

      {:error, changeset} ->
        {:noreply, assign(socket, :new_team_changeset, changeset)}
    end
  end

  @impl true
  def handle_event("remove_team", %{"team-id" => team_id}, socket) do
    team = Drafts.get_team!(team_id)

    case Drafts.delete_team(team) do
      {:ok, _team} ->
        teams = Drafts.list_teams(socket.assigns.draft.id)

        {:noreply,
         socket
         |> assign(:teams, teams)
         |> put_flash(:info, "Team removed successfully!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to remove team")}
    end
  end

  @impl true
  def handle_event("move_team_up", %{"team-id" => team_id}, socket) do
    team_id = String.to_integer(team_id)
    teams = socket.assigns.teams

    # Find the team and its current position
    case Enum.find_index(teams, &(&1.id == team_id)) do
      0 ->
        # Already at the top
        {:noreply, socket}

      index when index > 0 ->
        # Swap with the team above
        team_above = Enum.at(teams, index - 1)
        current_team = Enum.at(teams, index)

        new_order =
          teams
          |> Enum.map(& &1.id)
          |> List.replace_at(index - 1, current_team.id)
          |> List.replace_at(index, team_above.id)

        case Drafts.reorder_teams(socket.assigns.draft.id, new_order) do
          {:ok, _} ->
            updated_teams = Drafts.list_teams(socket.assigns.draft.id)

            {:noreply,
             socket
             |> assign(:teams, updated_teams)
             |> put_flash(:info, "#{current_team.name} moved up in pick order")}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Failed to reorder teams")}
        end

      nil ->
        {:noreply, put_flash(socket, :error, "Team not found")}
    end
  end

  @impl true
  def handle_event("reorder_teams", %{"team_order" => team_order}, socket) do
    # Convert string IDs to integers, filtering out any nil values
    team_ids =
      team_order
      |> Enum.filter(&(&1 != nil and &1 != ""))
      |> Enum.map(&String.to_integer/1)

    # Validate we have the correct number of teams
    expected_team_count = length(socket.assigns.teams)

    if length(team_ids) != expected_team_count do
      {:noreply,
       put_flash(
         socket,
         :error,
         "Invalid team order - expected #{expected_team_count} teams, got #{length(team_ids)}"
       )}
    else
      case Drafts.reorder_teams(socket.assigns.draft.id, team_ids) do
        {:ok, _} ->
          updated_teams = Drafts.list_teams(socket.assigns.draft.id)

          {:noreply,
           socket
           |> assign(:teams, updated_teams)
           |> put_flash(:info, "Team order updated successfully")}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Failed to reorder teams")}
      end
    end
  end

  @impl true
  def handle_event("move_team_down", %{"team-id" => team_id}, socket) do
    team_id = String.to_integer(team_id)
    teams = socket.assigns.teams

    # Find the team and its current position
    case Enum.find_index(teams, &(&1.id == team_id)) do
      index when index == length(teams) - 1 ->
        # Already at the bottom
        {:noreply, socket}

      index when index >= 0 and index < length(teams) - 1 ->
        # Swap with the team below
        current_team = Enum.at(teams, index)
        team_below = Enum.at(teams, index + 1)

        new_order =
          teams
          |> Enum.map(& &1.id)
          |> List.replace_at(index, team_below.id)
          |> List.replace_at(index + 1, current_team.id)

        case Drafts.reorder_teams(socket.assigns.draft.id, new_order) do
          {:ok, _} ->
            updated_teams = Drafts.list_teams(socket.assigns.draft.id)

            {:noreply,
             socket
             |> assign(:teams, updated_teams)
             |> put_flash(:info, "#{current_team.name} moved down in pick order")}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Failed to reorder teams")}
        end

      nil ->
        {:noreply, put_flash(socket, :error, "Team not found")}
    end
  end

  @impl true
  def handle_event("champion_selected", %{"player" => %{"champion_id" => champion_id}}, socket) do
    case champion_id do
      "" ->
        {:noreply, assign(socket, :champion_skins, [])}

      _ ->
        champion_id = String.to_integer(champion_id)
        skins = LoL.list_champion_skins(champion_id)
        {:noreply, assign(socket, :champion_skins, skins)}
    end
  end

  @impl true
  def handle_event("edit_champion_selected", %{"champion_id" => champion_id}, socket) do
    case champion_id do
      "" ->
        {:noreply, assign(socket, :champion_skins, [])}

      _ ->
        champion_id = String.to_integer(champion_id)
        skins = LoL.list_champion_skins(champion_id)
        {:noreply, assign(socket, :champion_skins, skins)}
    end
  end

  @impl true
  def handle_event("add_player", %{"player" => player_params}, socket) do
    draft = socket.assigns.draft

    case Drafts.create_player(draft.id, player_params) do
      {:ok, _player} ->
        players = Drafts.list_players(draft.id)

        {:noreply,
         socket
         |> assign(:players, players)
         |> push_event("clear-form", %{form: "player-form"})
         |> put_flash(:info, "Player added successfully!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to add player")}
    end
  end

  @impl true
  def handle_event("show_captain_team_selector", %{"player-id" => player_id}, socket) do
    player_id = String.to_integer(player_id)
    {:noreply, assign(socket, :captain_player_id, player_id)}
  end

  @impl true
  def handle_event("cancel_captain_selection", _params, socket) do
    {:noreply, assign(socket, :captain_player_id, nil)}
  end

  @impl true
  def handle_event(
        "set_captain_for_team",
        %{"player-id" => player_id, "team-id" => team_id},
        socket
      ) do
    player_id = String.to_integer(player_id)
    team_id = String.to_integer(team_id)

    case Drafts.set_captain(player_id, team_id) do
      {:ok, _player} ->
        players = Drafts.list_players(socket.assigns.draft.id)

        {:noreply,
         socket
         |> assign(:players, players)
         |> assign(:captain_player_id, nil)
         |> put_flash(:info, "Captain set successfully!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to set captain")}
    end
  end

  @impl true
  def handle_event("unset_captain", %{"player-id" => player_id}, socket) do
    player_id = String.to_integer(player_id)

    case Drafts.unset_captain(player_id) do
      {:ok, _player} ->
        players = Drafts.list_players(socket.assigns.draft.id)

        {:noreply,
         socket
         |> assign(:players, players)
         |> put_flash(:info, "Captain removed successfully!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to remove captain")}
    end
  end

  @impl true
  def handle_event("remove_player", %{"player-id" => player_id}, socket) do
    player = Drafts.get_player!(player_id)

    case Drafts.delete_player(player) do
      {:ok, _player} ->
        players = Drafts.list_players(socket.assigns.draft.id)

        {:noreply,
         socket
         |> assign(:players, players)
         |> put_flash(:info, "Player removed successfully!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to remove player")}
    end
  end

  @impl true
  def handle_event("finalize_draft", _params, socket) do
    draft = socket.assigns.draft
    teams = socket.assigns.teams
    players = socket.assigns.players

    # Calculate required players based on format
    # When captains are required (either via captain_mode or captains_required flag),
    # we only need 4 picks per team since the captain is pre-assigned
    required_players_per_team =
      if draft.format == :captain_mode or draft.captains_required, do: 4, else: 5

    # Validate captain requirements if needed (captain mode or captains_required flag)
    captain_validation =
      if draft.format == :captain_mode or draft.captains_required do
        Drafts.validate_captain_mode_requirements(draft.id)
      else
        :ok
      end

    cond do
      length(teams) < 2 ->
        {:noreply, put_flash(socket, :error, "Draft needs at least 2 teams")}

      captain_validation != :ok ->
        {:error, message} = captain_validation
        {:noreply, put_flash(socket, :error, message)}

      length(players) < length(teams) * required_players_per_team ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Draft needs at least #{length(teams) * required_players_per_team} players (#{required_players_per_team} per team)"
         )}

      true ->
        case Drafts.update_draft(draft, %{status: :setup}) do
          {:ok, updated_draft} ->
            # Get or create mock draft when finalizing setup
            case AceApp.MockDrafts.get_or_create_mock_draft_for_draft(updated_draft.id) do
              {:ok, _mock_draft} ->
                # Send message to refresh sidebar navigation
                send_update(AceAppWeb.Components.SidebarNav, id: "sidebar-nav", refresh: true)

                {:noreply,
                 socket
                 |> put_flash(
                   :info,
                   "Draft is ready! Mock draft system enabled. Share the links to get started."
                 )
                 |> push_navigate(to: "/drafts/links/#{updated_draft.organizer_token}")}

              {:error, _changeset} ->
                # Still proceed even if mock draft creation fails
                send_update(AceAppWeb.Components.SidebarNav, id: "sidebar-nav", refresh: true)

                {:noreply,
                 socket
                 |> put_flash(:warning, "Draft is ready, but mock draft creation failed.")
                 |> push_navigate(to: "/drafts/links/#{updated_draft.organizer_token}")}
            end

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to finalize draft")}
        end
    end
  end

  # Private helper functions

  defp get_next_step(:basic_info), do: :teams
  defp get_next_step(:teams), do: :players
  defp get_next_step(:players), do: :complete
  defp get_next_step(step), do: step

  defp get_prev_step(:teams), do: :basic_info
  defp get_prev_step(:players), do: :teams
  defp get_prev_step(:complete), do: :players
  defp get_prev_step(step), do: step

  defp can_proceed?(:teams, assigns) do
    length(assigns.teams) >= 2
  end

  defp can_proceed?(:players, assigns) do
    length(assigns.players) >= length(assigns.teams) * 5
  end

  defp can_proceed?(_step, _assigns), do: true

  # File upload handlers

  defp handle_logo_progress(_entry, _upload_entry, socket), do: {:noreply, socket}

  defp handle_csv_progress(entry, _upload, socket) when entry.done? do
    IO.puts("CSV upload complete! Processing...")
    # CSV upload is complete, process it automatically
    case consume_uploaded_entries(socket, :csv_file, &process_csv_upload/2) do
      [csv_content] ->
        import_type =
          case socket.assigns.csv_import_step do
            :teams -> "teams"
            :players -> "players"
          end

        case parse_csv_data(csv_content) do
          {:ok, [_ | _] = parsed_data} ->
            # Use the cleaned CSV content for validation
            cleaned_content =
              csv_content
              |> String.replace("\r\n", "\n")
              |> String.replace("\r", "\n")
              |> clean_csv_quotes()

            case Imports.validate_csv_import(
                   socket.assigns.draft.id,
                   cleaned_content,
                   import_type
                 ) do
              {:ok, _validation_results} ->
                # Auto-import immediately after validation
                socket_with_data =
                  socket
                  |> assign(:csv_preview_data, parsed_data)
                  |> assign(:csv_validation_errors, [])

                # Trigger the import based on type
                case socket.assigns.csv_import_step do
                  :teams -> import_teams_from_csv(socket_with_data)
                  :players -> import_players_from_csv(socket_with_data)
                end

              {:error, errors} when is_list(errors) ->
                {:noreply,
                 socket
                 |> assign(:csv_preview_data, parsed_data)
                 |> assign(:csv_validation_errors, errors)
                 |> put_flash(:error, "CSV has validation errors. Please review.")}

              {:error, error} ->
                {:noreply,
                 socket
                 |> put_flash(:error, "Validation failed: #{format_error_message(error)}")}
            end

          {:ok, _empty_data} ->
            {:noreply,
             socket
             |> put_flash(:error, "CSV file appears to be empty or contains no valid data rows.")}

          {:error, error} ->
            {:noreply,
             socket
             |> put_flash(:error, "Invalid CSV file format: #{format_error_message(error)}")}
        end

      [] ->
        {:noreply, socket}

      _other ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to process the uploaded file. Please try again.")}
    end
  rescue
    _error ->
      {:noreply,
       socket
       |> put_flash(
         :error,
         "An error occurred while processing your CSV file. Please check the file format and try again."
       )}
  end

  defp handle_csv_progress(entry, _upload, socket) do
    IO.puts("CSV progress called: done=#{entry.done?}, progress=#{entry.progress}")
    {:noreply, socket}
  end

  defp handle_team_logo_upload(socket, team_params) do
    uploaded_files =
      consume_uploaded_entries(socket, :team_logo, fn %{path: path}, entry ->
        # Ensure upload directory exists
        upload_dir = AceApp.Files.ensure_upload_directory!(socket.assigns.draft.id)

        # Create unique filename
        timestamp = System.system_time(:second)
        extension = Path.extname(entry.client_name)
        filename = "#{timestamp}_#{Path.basename(entry.client_name, extension)}#{extension}"
        dest = Path.join(upload_dir, filename)

        # Copy file to destination
        File.cp!(path, dest)

        {:ok,
         %{
           filename: filename,
           original_path: dest,
           content_type: entry.client_type,
           file_size: entry.client_size
         }}
      end)

    # Update team params with logo info if file was uploaded
    team_params =
      case uploaded_files do
        [logo_info | _] ->
          # Generate web URL for the logo
          web_url = "/uploads/drafts/#{socket.assigns.draft.id}/logos/#{logo_info.filename}"

          team_params
          |> Map.put("logo_url", web_url)
          |> Map.put("logo_file_size", logo_info.file_size)
          |> Map.put("logo_content_type", logo_info.content_type)

        [] ->
          team_params
      end

    {team_params, uploaded_files}
  end

  defp process_team_logo_files(team, uploaded_files) do
    case uploaded_files do
      [logo_info | _] ->
        # Create file upload record
        case AceApp.Files.create_file_upload(%{
               draft_id: team.draft_id,
               filename: logo_info.filename,
               content_type: logo_info.content_type,
               file_size: logo_info.file_size,
               file_path: logo_info.original_path,
               upload_status: "completed",
               file_type: "team_logo"
             }) do
          {:ok, file_upload} ->
            # Update team with file upload reference
            AceApp.Drafts.update_team(team, %{logo_upload_id: file_upload.id})

          {:error, _changeset} ->
            # Log error but don't fail team creation
            :ok
        end

      [] ->
        :ok
    end
  end

  defp upload_error_to_string(:too_large), do: "File size too large (max 2MB)"
  defp upload_error_to_string(:not_accepted), do: "Invalid file type (only PNG, JPG, SVG allowed)"
  defp upload_error_to_string(:too_many_files), do: "Only one logo file allowed"
  defp upload_error_to_string(error), do: "Upload error: #{error}"

  # Helper function for team gradient colors
  defp team_gradient_class(index) do
    case rem(index, 5) do
      0 -> "bg-gradient-to-br from-blue-500 to-blue-600"
      1 -> "bg-gradient-to-br from-red-500 to-red-600"
      2 -> "bg-gradient-to-br from-green-500 to-green-600"
      3 -> "bg-gradient-to-br from-purple-500 to-purple-600"
      4 -> "bg-gradient-to-br from-yellow-500 to-yellow-600"
      _ -> "bg-gradient-to-br from-slate-500 to-slate-600"
    end
  end

  # CSV Import helper functions

  defp process_csv_upload(meta, _entry) do
    case File.read(meta.path) do
      {:ok, content} -> {:ok, content}
      {:error, _reason} -> {:postpone, "Failed to read uploaded file"}
    end
  end

  defp parse_csv_data(csv_content) do
    try do
      # First try to clean up common CSV formatting issues
      cleaned_content =
        csv_content
        # Normalize line endings
        |> String.replace("\r\n", "\n")
        # Handle old Mac line endings
        |> String.replace("\r", "\n")
        # Fix quote issues
        |> clean_csv_quotes()

      case NimbleCSV.RFC4180.parse_string(cleaned_content, skip_headers: false) do
        [] ->
          {:error, "CSV file is empty"}

        [headers | rows] ->
          # Convert rows to maps with header keys
          parsed_rows =
            Enum.map(rows, fn row ->
              headers
              |> Enum.zip(row)
              |> Enum.into(%{})
            end)

          {:ok, parsed_rows}
      end
    rescue
      error -> {:error, "Failed to parse CSV: #{inspect(error)}"}
    end
  end

  defp clean_csv_quotes(content) do
    content
    |> String.split("\n")
    |> Enum.map(&clean_csv_line/1)
    |> Enum.join("\n")
  end

  defp clean_csv_line(line) do
    # Handle lines with inconsistent quoting - fix the specific pattern from the error
    line
    # Fix: ", "quoted", " -> ,"quoted",
    |> String.replace(~r/,\s+"([^"]*)",\s*/, ",\"\\1\",")
    # Fix: ,"quoted", -> ,"quoted",
    |> String.replace(~r/,\s*"([^"]*)",\s*/, ",\"\\1\",")
    # Fix: , unquoted , -> ,unquoted,
    |> String.replace(~r/,\s+([^",]+)\s*,/, ",\\1,")
    # Fix end of line spaces
    |> String.replace(~r/,\s+([^",]+)\s*$/, ",\\1")
  end

  defp import_teams_from_csv(socket) do
    draft_id = socket.assigns.draft.id

    results =
      Enum.map(socket.assigns.csv_preview_data, fn team_data ->
        team_params = %{
          "name" => team_data["name"] || team_data["Name"],
          "logo_url" => team_data["logo_url"] || team_data["Logo URL"],
          "pick_order_position" => team_data["pick_order_position"] || team_data["Pick Order"]
        }

        Drafts.create_team(draft_id, team_params)
      end)

    successful = Enum.count(results, fn {status, _} -> status == :ok end)
    failed = Enum.count(results, fn {status, _} -> status == :error end)

    teams = Drafts.list_teams(draft_id)

    {:noreply,
     socket
     |> assign(:teams, teams)
     |> assign(:csv_import_step, nil)
     |> assign(:csv_preview_data, [])
     |> assign(:csv_validation_errors, [])
     |> put_flash(
       :info,
       "Imported #{successful} teams successfully#{if failed > 0, do: ", #{failed} failed", else: ""}!"
     )}
  end

  defp import_players_from_csv(socket) do
    draft_id = socket.assigns.draft.id

    results =
      Enum.map(socket.assigns.csv_preview_data, fn player_data ->
        try do
          # Handle preferred roles - split comma-separated values
          preferred_roles =
            case player_data["preferred_roles"] || player_data["Preferred Roles"] do
              nil ->
                []

              roles_str when is_binary(roles_str) ->
                roles_str
                |> String.split(",")
                |> Enum.map(&String.trim/1)
                |> Enum.map(&String.downcase/1)
                |> Enum.filter(&(&1 != ""))
                |> Enum.map(&String.to_atom/1)
                |> Enum.filter(&(&1 in [:top, :jungle, :mid, :adc, :support]))

              roles ->
                roles
            end

          # Player creation params (only player-specific fields)
          player_params = %{
            "display_name" => player_data["display_name"] || player_data["Display Name"],
            "organizer_notes" => player_data["organizer_notes"] || player_data["Organizer Notes"],
            "preferred_roles" => preferred_roles
          }

          # Create the player first
          case Drafts.create_player(draft_id, player_params) do
            {:ok, player} ->
              # If we have account data, create a player account
              summoner_name = player_data["summoner_name"] || player_data["Summoner Name"]

              if summoner_name && String.trim(summoner_name) != "" do
                account_params = %{
                  "summoner_name" => summoner_name,
                  "rank_tier" => player_data["rank_tier"] || player_data["Rank Tier"],
                  "rank_division" =>
                    player_data["rank_division"] || player_data["Rank Division"],
                  "server_region" =>
                    player_data["server_region"] || player_data["Server Region"] || "NA"
                }

                # Ignore account creation errors - player is already created successfully
                case Drafts.create_player_account(player, account_params) do
                  {:ok, _account} -> {:ok, player}
                  {:error, _} -> {:ok, player}
                end
              else
                {:ok, player}
              end

            error ->
              error
          end
        rescue
          e ->
            {:error, "Failed to import player: #{inspect(e)}"}
        end
      end)

    successful = Enum.count(results, fn {status, _} -> status == :ok end)
    failed = Enum.count(results, fn {status, _} -> status == :error end)

    # Log any errors for debugging
    Enum.each(results, fn
      {:error, reason} -> IO.inspect(reason, label: "Player import error")
      _ -> :ok
    end)

    players = Drafts.list_players(draft_id)

    IO.puts("Total CSV rows: #{length(socket.assigns.csv_preview_data)}")
    IO.puts("Import results: #{successful} successful, #{failed} failed")
    IO.puts("Players in DB after import: #{length(players)}")

    {:noreply,
     socket
     |> assign(:players, players)
     |> assign(:csv_import_step, nil)
     |> assign(:csv_preview_data, [])
     |> assign(:csv_validation_errors, [])
     |> put_flash(
       :info,
       "Imported #{successful} players successfully#{if failed > 0, do: ", #{failed} failed", else: ""}!"
     )}
  end

  defp generate_csv_template("teams") do
    headers = ["name", "logo_url", "pick_order_position"]
    example_row = ["Team Alpha", "https://example.com/logo.png", "1"]

    [headers, example_row]
    |> NimbleCSV.RFC4180.dump_to_iodata()
    |> IO.iodata_to_binary()
  end

  defp generate_csv_template("players") do
    headers = [
      "display_name",
      "preferred_roles",
      "summoner_name",
      "rank_tier",
      "rank_division",
      "server_region",
      "organizer_notes"
    ]

    example_row = [
      "John Doe",
      "adc,mid",
      "JohnDoe123",
      "gold",
      "ii",
      "NA1",
      "Strong mechanical player"
    ]

    [headers, example_row]
    |> NimbleCSV.RFC4180.dump_to_iodata()
    |> IO.iodata_to_binary()
  end

  defp format_error_message(error) when is_binary(error), do: error
  defp format_error_message(%{message: message}), do: message
  defp format_error_message(_error), do: "Please check your CSV file format and try again"

  # Discord webhook validation helper
  defp maybe_validate_discord_webhook(draft, draft_params) do
    case Map.get(draft_params, "discord_webhook_url") do
      url when is_binary(url) and url != "" ->
        case AceApp.Discord.validate_webhook(url) do
          {:ok, _webhook_info} ->
            {:ok, updated_draft} = Drafts.update_draft(draft, %{discord_webhook_validated: true})
            updated_draft

          {:error, _reason} ->
            # Still create the draft but mark webhook as not validated
            {:ok, updated_draft} = Drafts.update_draft(draft, %{discord_webhook_validated: false})
            updated_draft
        end

      _ ->
        draft
    end
  end
end
