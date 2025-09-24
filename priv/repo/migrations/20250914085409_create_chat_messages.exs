defmodule AceApp.Repo.Migrations.CreateChatMessages do
  use Ecto.Migration

  def change do
    create table(:chat_messages) do
      add :content, :text, null: false
      add :message_type, :string, null: false, default: "message"
      add :sender_type, :string, null: false
      add :sender_name, :string, null: false
      add :metadata, :map, default: %{}

      add :draft_id, references(:drafts, on_delete: :delete_all), null: false
      add :team_id, references(:teams, on_delete: :nilify_all), null: true

      timestamps(type: :utc_datetime)
    end

    create index(:chat_messages, [:draft_id])
    create index(:chat_messages, [:team_id])
    create index(:chat_messages, [:inserted_at])
    create index(:chat_messages, [:draft_id, :team_id])
    create index(:chat_messages, [:draft_id, :message_type])
  end
end