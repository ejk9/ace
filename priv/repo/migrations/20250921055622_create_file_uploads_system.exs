defmodule AceApp.Repo.Migrations.CreateFileUploadsSystem do
  use Ecto.Migration

  def change do
    # Create file_uploads table for team logos and future CSV imports
    create table(:file_uploads) do
      add :draft_id, references(:drafts, on_delete: :delete_all), null: false
      add :filename, :string, null: false
      add :content_type, :string, null: false
      add :file_size, :integer, null: false
      add :file_path, :string, null: false
      add :upload_status, :string, null: false, default: "uploading"
      add :uploaded_by, :string
      add :file_type, :string, null: false, default: "team_logo"

      timestamps()
    end

    create index(:file_uploads, [:draft_id])
    create index(:file_uploads, [:upload_status])
    create index(:file_uploads, [:file_type])

    # Add logo upload relationship to teams table
    alter table(:teams) do
      add :logo_upload_id, references(:file_uploads, on_delete: :nilify_all)
      add :logo_file_size, :integer
      add :logo_content_type, :string
    end

    create index(:teams, [:logo_upload_id])
  end
end