defmodule AceAppWeb.CsvImportLive do
  use AceAppWeb, :live_view

  alias AceApp.{Drafts, Imports}

  @impl true
  def mount(%{"draft_id" => draft_id}, _session, socket) do
    draft = Drafts.get_draft!(draft_id)
    
    {:ok,
     socket
     |> assign(:draft, draft)
     |> assign(:page_title, "CSV Import - #{draft.name}")
     |> assign(:import_type, nil)
     |> assign(:upload_state, :select_type)  # :select_type, :upload, :preview, :importing, :completed
     |> assign(:csv_content, nil)
     |> assign(:parsed_data, nil)
     |> assign(:validation_errors, [])
     |> assign(:import_job, nil)
     |> assign(:import_history, Imports.list_import_jobs(draft.id))
     |> assign(:show_templates, false)
     |> allow_upload(:csv_file,
         accept: ~w(.csv),
         max_entries: 1,
         max_file_size: 5_242_880,  # 5MB
         auto_upload: false)}
  end

  @impl true
  def handle_event("select_import_type", %{"type" => type}, socket) do
    {:noreply,
     socket
     |> assign(:import_type, type)
     |> assign(:upload_state, :upload)}
  end

  @impl true
  def handle_event("back_to_type_selection", _params, socket) do
    {:noreply,
     socket
     |> assign(:import_type, nil)
     |> assign(:upload_state, :select_type)
     |> assign(:csv_content, nil)
     |> assign(:parsed_data, nil)
     |> assign(:validation_errors, [])}
  end

  @impl true
  def handle_event("upload_csv", _params, socket) do
    case consume_uploaded_entries(socket, :csv_file, &process_csv_upload/2) do
      [{csv_content, _meta}] ->
        case parse_csv_data(csv_content) do
          {:ok, parsed_data} ->
            case Imports.validate_csv_import(socket.assigns.draft.id, csv_content, socket.assigns.import_type) do
              {:ok, _validation_results} ->
                {:noreply,
                 socket
                 |> assign(:csv_content, csv_content)
                 |> assign(:parsed_data, parsed_data)
                 |> assign(:validation_errors, [])
                 |> assign(:upload_state, :preview)
                 |> put_flash(:info, "CSV processed successfully!")}
              
              {:error, errors} when is_list(errors) ->
                {:noreply,
                 socket
                 |> assign(:csv_content, csv_content)
                 |> assign(:parsed_data, parsed_data)
                 |> assign(:validation_errors, errors)
                 |> assign(:upload_state, :preview)
                 |> put_flash(:error, "CSV has validation errors")}
              
              {:error, error} ->
                {:noreply,
                 socket
                 |> put_flash(:error, "Validation failed: #{error}")
                 |> assign(:upload_state, :upload)}
            end
          
          {:error, error} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to parse CSV: #{error}")
             |> assign(:upload_state, :upload)}
        end
      
      [] ->
        {:noreply,
         socket
         |> put_flash(:error, "Please select a CSV file to upload")
         |> assign(:upload_state, :upload)}
    end
  end

  @impl true
  def handle_event("start_import", _params, socket) do
    case Imports.start_csv_import_from_content(
      socket.assigns.draft.id,
      socket.assigns.csv_content,
      socket.assigns.import_type,
      "organizer"
    ) do
      {:ok, import_job} ->
        {:noreply,
         socket
         |> assign(:import_job, import_job)
         |> assign(:upload_state, :importing)
         |> put_flash(:info, "Import started! Processing #{import_job.total_records} records...")
         |> tap(fn _ -> schedule_import_progress_check() end)}
      
      {:error, error} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to start import: #{inspect(error)}")
         |> assign(:upload_state, :preview)}
    end
  end

  @impl true
  def handle_event("back_to_upload", _params, socket) do
    {:noreply,
     socket
     |> assign(:upload_state, :upload)
     |> assign(:csv_content, nil)
     |> assign(:parsed_data, nil)
     |> assign(:validation_errors, [])}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :csv_file, ref)}
  end

  @impl true 
  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("download_template", _params, socket) do
    template_content = generate_csv_template(socket.assigns.import_type)
    
    {:noreply,
     socket
     |> push_event("download_csv", %{
       content: template_content,
       filename: "#{socket.assigns.import_type}_import_template.csv"
     })}
  end

  @impl true
  def handle_event("start_new_import", _params, socket) do
    {:noreply,
     socket
     |> assign(:import_type, nil)
     |> assign(:upload_state, :select_type)
     |> assign(:csv_content, nil)
     |> assign(:parsed_data, nil)
     |> assign(:validation_errors, [])
     |> assign(:import_job, nil)
     |> assign(:import_history, Imports.list_import_jobs(socket.assigns.draft.id))}
  end

  @impl true
  def handle_info(:check_import_progress, socket) do
    if socket.assigns.import_job do
      updated_job = Imports.get_import_job(socket.assigns.import_job.id)
      
      case updated_job.status do
        status when status in ["completed", "completed_with_errors", "failed"] ->
          {:noreply,
           socket
           |> assign(:import_job, updated_job)
           |> assign(:upload_state, :completed)
           |> assign(:import_history, Imports.list_import_jobs(socket.assigns.draft.id))
           |> put_flash(:info, format_import_completion_message(updated_job))}
        
        _ ->
          schedule_import_progress_check()
          {:noreply,
           socket
           |> assign(:import_job, updated_job)}
      end
    else
      {:noreply, socket}
    end
  end

  # Private functions

  defp process_csv_upload({path, _upload}, _entry) do
    case File.read(path) do
      {:ok, content} -> {content, %{}}
      {:error, _reason} -> {:error, "Failed to read uploaded file"}
    end
  end

  defp parse_csv_data(csv_content) do
    try do
      case NimbleCSV.RFC4180.parse_string(csv_content, skip_headers: false) do
        [] -> {:error, "CSV file is empty"}
        [headers | rows] ->
          # Convert rows to maps with header keys
          parsed_rows = Enum.map(rows, fn row ->
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

  defp schedule_import_progress_check do
    Process.send_after(self(), :check_import_progress, 1000)  # Check every second
  end

  defp format_import_completion_message(import_job) do
    case import_job.status do
      "completed" ->
        "Import completed successfully! #{import_job.successful_records} records imported."
      
      "completed_with_errors" ->
        "Import completed with #{import_job.failed_records} errors. #{import_job.successful_records} records imported successfully."
      
      "failed" ->
        "Import failed. Please check the error details and try again."
    end
  end

  defp generate_csv_template("players") do
    headers = ["display_name", "preferred_roles", "summoner_name", "rank_tier", "rank_division", "server_region", "organizer_notes", "champion_name", "skin_name"]
    example_row = ["John Doe", "adc,mid", "JohnDoe123", "gold", "ii", "NA1", "Strong mechanical player", "Jinx", "Pool Party Jinx"]
    
    [headers, example_row]
    |> NimbleCSV.RFC4180.dump_to_iodata()
    |> IO.iodata_to_binary()
  end

  defp generate_csv_template("teams") do
    headers = ["name", "logo_url", "pick_order_position"]
    example_row = ["Team Alpha", "https://example.com/logo.png", "1"]
    
    [headers, example_row]
    |> NimbleCSV.RFC4180.dump_to_iodata()
    |> IO.iodata_to_binary()
  end

  # Helper functions for template
  defp step_class(current_state, step) do
    cond do
      step_completed?(current_state, step) ->
        "text-blue-600 border-blue-600 bg-blue-50"
      current_state == step ->
        "text-blue-600 border-blue-600"
      true ->
        "text-gray-400 border-gray-300"
    end
  end

  defp step_completed?(current_state, step) do
    step_order = [:select_type, :upload, :preview, :importing, :completed]
    current_index = Enum.find_index(step_order, &(&1 == current_state)) || 0
    step_index = Enum.find_index(step_order, &(&1 == step)) || 0
    current_index > step_index
  end

  defp error_to_string(:too_large), do: "File is too large (max 5MB)"
  defp error_to_string(:not_accepted), do: "Only CSV files are allowed"
  defp error_to_string(:too_many_files), do: "Only one file at a time"
  defp error_to_string(other), do: "Upload error: #{inspect(other)}"
end