defmodule AceApp.Files do
  @moduledoc """
  The Files context for managing file uploads.
  """

  import Ecto.Query, warn: false
  alias AceApp.Repo
  alias AceApp.Files.FileUpload

  @doc """
  Creates a file upload record.
  """
  def create_file_upload(attrs \\ %{}) do
    %FileUpload{}
    |> FileUpload.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a file upload by ID.
  """
  def get_file_upload!(id), do: Repo.get!(FileUpload, id)

  @doc """
  Gets a file upload by ID.
  """
  def get_file_upload(id), do: Repo.get(FileUpload, id)

  @doc """
  Updates a file upload.
  """
  def update_file_upload(%FileUpload{} = file_upload, attrs) do
    file_upload
    |> FileUpload.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a file upload and removes the file from disk.
  """
  def delete_file_upload(%FileUpload{} = file_upload) do
    # Remove file from disk
    if File.exists?(file_upload.file_path) do
      File.rm(file_upload.file_path)
    end

    # Remove thumbnails if they exist
    remove_generated_files(file_upload.file_path)

    Repo.delete(file_upload)
  end

  @doc """
  Lists file uploads for a specific draft.
  """
  def list_file_uploads_for_draft(draft_id) do
    FileUpload
    |> where([f], f.draft_id == ^draft_id)
    |> order_by([f], desc: f.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists team logo uploads for a specific draft.
  """
  def list_team_logos_for_draft(draft_id) do
    FileUpload
    |> where([f], f.draft_id == ^draft_id and f.file_type == "team_logo")
    |> where([f], f.upload_status == "completed")
    |> order_by([f], desc: f.inserted_at)
    |> Repo.all()
  end

  @doc """
  Marks a file upload as completed.
  """
  def mark_upload_completed(file_upload_id) do
    file_upload = get_file_upload!(file_upload_id)
    update_file_upload(file_upload, %{upload_status: "completed"})
  end

  @doc """
  Marks a file upload as failed.
  """
  def mark_upload_failed(file_upload_id, _error_reason \\ nil) do
    file_upload = get_file_upload!(file_upload_id)
    update_file_upload(file_upload, %{upload_status: "failed"})
  end

  @doc """
  Cleans up all files for a draft when it's deleted.
  """
  def cleanup_draft_files(draft_id) do
    upload_dir = upload_directory_for_draft(draft_id)
    if File.exists?(upload_dir) do
      File.rm_rf!(upload_dir)
    end
  end

  @doc """
  Gets the upload directory for a specific draft.
  """
  def upload_directory_for_draft(draft_id) do
    Path.join(["priv", "static", "uploads", "drafts", "#{draft_id}"])
  end

  @doc """
  Gets the logos directory for a specific draft.
  """
  def logos_directory_for_draft(draft_id) do
    Path.join([upload_directory_for_draft(draft_id), "logos"])
  end

  @doc """
  Ensures the upload directory exists for a draft.
  """
  def ensure_upload_directory!(draft_id) do
    logo_dir = logos_directory_for_draft(draft_id)
    File.mkdir_p!(logo_dir)
    
    # Create subdirectories for different sizes
    File.mkdir_p!(Path.join(logo_dir, "thumbnails"))
    File.mkdir_p!(Path.join(logo_dir, "medium"))
    
    logo_dir
  end

  # Private functions

  defp remove_generated_files(original_path) do
    base_name = Path.basename(original_path, Path.extname(original_path))
    base_dir = Path.dirname(original_path)
    
    # Remove thumbnails and medium versions
    thumbnail_path = Path.join([Path.dirname(base_dir), "thumbnails", "#{base_name}.png"])
    medium_path = Path.join([Path.dirname(base_dir), "medium", "#{base_name}.png"])
    
    if File.exists?(thumbnail_path), do: File.rm(thumbnail_path)
    if File.exists?(medium_path), do: File.rm(medium_path)
  end
end