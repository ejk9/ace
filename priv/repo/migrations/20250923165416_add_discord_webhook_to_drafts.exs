defmodule AceApp.Repo.Migrations.AddDiscordWebhookToDrafts do
  use Ecto.Migration

  def change do
    alter table(:drafts) do
      add :discord_webhook_url, :string, size: 2000
      add :discord_webhook_validated, :boolean, default: false
      add :discord_notifications_enabled, :boolean, default: true
    end
  end
end
