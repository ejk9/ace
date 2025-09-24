defmodule AceApp.Files.FileUpload do
  use Ecto.Schema
  import Ecto.Changeset

  alias AceApp.Drafts.Draft

  @upload_statuses ["uploading", "completed", "failed", "deleted"]
  @file_types ["team_logo", "csv_import"]
  @allowed_content_types ["image/png", "image/jpeg", "image/jpg", "image/svg+xml", "image/webp"]
  @max_file_size 10_485_760  # 10MB

  schema "file_uploads" do
    field :filename, :string
    field :content_type, :string
    field :file_size, :integer
    field :file_path, :string
    field :upload_status, :string, default: "uploading"
    field :uploaded_by, :string
    field :file_type, :string, default: "team_logo"

    belongs_to :draft, Draft

    timestamps()
  end

  @doc false
  def changeset(file_upload, attrs) do
    file_upload
    |> cast(attrs, [
      :draft_id,
      :filename,
      :content_type,
      :file_size,
      :file_path,
      :upload_status,
      :uploaded_by,
      :file_type
    ])
    |> validate_required([
      :draft_id,
      :filename,
      :content_type,
      :file_size,
      :file_path,
      :file_type
    ])
    |> validate_inclusion(:upload_status, @upload_statuses)
    |> validate_inclusion(:file_type, @file_types)
    |> validate_inclusion(:content_type, @allowed_content_types,
      message: "must be a valid image type (PNG, JPG, or SVG)")
    |> validate_number(:file_size,
      greater_than: 0,
      less_than_or_equal_to: @max_file_size,
      message: "must be less than 2MB")
    |> foreign_key_constraint(:draft_id)
  end

  @doc """
  Returns the maximum allowed file size in bytes.
  """
  def max_file_size, do: @max_file_size

  @doc """
  Returns the list of allowed content types.
  """
  def allowed_content_types, do: @allowed_content_types

  @doc """
  Returns the list of valid upload statuses.
  """
  def upload_statuses, do: @upload_statuses

  @doc """
  Returns the list of valid file types.
  """
  def file_types, do: @file_types

  @doc """
  Generates a web-accessible URL for the file.
  """
  def web_url(%__MODULE__{file_path: file_path}) do
    # Convert filesystem path to web path
    case String.split(file_path, "priv/static") do
      [_, web_path] -> web_path
      _ -> file_path
    end
  end

  @doc """
  Checks if the file upload is completed.
  """
  def completed?(%__MODULE__{upload_status: "completed"}), do: true
  def completed?(_), do: false

  @doc """
  Checks if the file upload failed.
  """
  def failed?(%__MODULE__{upload_status: "failed"}), do: true
  def failed?(_), do: false

  @doc """
  Checks if the file upload is still in progress.
  """
  def uploading?(%__MODULE__{upload_status: "uploading"}), do: true
  def uploading?(_), do: false
end