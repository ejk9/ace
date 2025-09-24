defmodule AceApp.Imports.ImportJob do
  use Ecto.Schema
  import Ecto.Changeset

  alias AceApp.Drafts.Draft
  alias AceApp.Files.FileUpload

  @import_types ["players", "teams"]
  @statuses ["pending", "processing", "completed", "completed_with_errors", "failed"]

  schema "import_jobs" do
    field :import_type, :string
    field :status, :string, default: "pending"
    field :total_records, :integer, default: 0
    field :processed_records, :integer, default: 0
    field :successful_records, :integer, default: 0
    field :failed_records, :integer, default: 0
    field :import_data, :map
    field :validation_errors, :map
    field :processing_errors, :map
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :imported_by, :string

    belongs_to :draft, Draft
    belongs_to :file_upload, FileUpload

    timestamps()
  end

  @doc false
  def changeset(import_job, attrs) do
    import_job
    |> cast(attrs, [
      :draft_id, :file_upload_id, :import_type, :status, :total_records,
      :processed_records, :successful_records, :failed_records, :import_data,
      :validation_errors, :processing_errors, :started_at, :completed_at, :imported_by
    ])
    |> validate_required([:draft_id, :import_type, :status])
    |> validate_inclusion(:import_type, @import_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:total_records, greater_than_or_equal_to: 0)
    |> validate_number(:processed_records, greater_than_or_equal_to: 0)
    |> validate_number(:successful_records, greater_than_or_equal_to: 0)
    |> validate_number(:failed_records, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:draft_id)
    |> foreign_key_constraint(:file_upload_id)
  end

  def import_types, do: @import_types
  def statuses, do: @statuses
end