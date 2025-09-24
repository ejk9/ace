defmodule AceApp.Repo.Migrations.CreateImportSystem do
  use Ecto.Migration

  def change do
    # Create import_jobs table to track CSV import operations
    create table(:import_jobs) do
      add :draft_id, references(:drafts, on_delete: :delete_all), null: false
      add :file_upload_id, references(:file_uploads, on_delete: :delete_all), null: true
      add :import_type, :string, null: false  # "players" or "teams"
      add :status, :string, null: false, default: "pending"  # pending, processing, completed, failed
      add :total_records, :integer, default: 0
      add :processed_records, :integer, default: 0
      add :successful_records, :integer, default: 0
      add :failed_records, :integer, default: 0
      add :import_data, :map  # Store parsed CSV data
      add :validation_errors, :map  # Store validation errors by row
      add :processing_errors, :map  # Store processing errors
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :imported_by, :string  # User identifier or role

      timestamps()
    end

    create index(:import_jobs, [:draft_id])
    create index(:import_jobs, [:status])
    create index(:import_jobs, [:import_type])
    create index(:import_jobs, [:file_upload_id])

    # Add import tracking fields to existing file_uploads table
    alter table(:file_uploads) do
      add :import_job_id, references(:import_jobs, on_delete: :nilify_all), null: true
      add :is_import_file, :boolean, default: false
    end

    create index(:file_uploads, [:import_job_id])
    create index(:file_uploads, [:is_import_file])
  end
end