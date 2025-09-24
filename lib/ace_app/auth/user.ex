defmodule AceApp.Auth.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field(:discord_id, :string)
    field(:discord_username, :string)
    field(:discord_discriminator, :string)
    field(:discord_avatar_url, :string)
    field(:discord_email, :string)
    field(:is_admin, :boolean, default: false)
    field(:last_login_at, :utc_datetime)

    has_many(:drafts, AceApp.Drafts.Draft)
    has_many(:user_sessions, AceApp.Auth.UserSession)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :discord_id,
      :discord_username,
      :discord_discriminator,
      :discord_avatar_url,
      :discord_email,
      :is_admin,
      :last_login_at
    ])
    |> validate_required([:discord_id, :discord_username])
    |> unique_constraint(:discord_id)
    |> validate_length(:discord_username, min: 1, max: 32)
  end

  @doc """
  Changeset for creating/updating a user from Discord OAuth data
  """
  def discord_changeset(user, discord_data) do
    # Check if this Discord ID should have admin privileges
    is_admin = is_admin_discord_id?(discord_data["id"])
    
    user
    |> cast(%{
      discord_id: discord_data["id"],
      discord_username: discord_data["username"],
      discord_discriminator: discord_data["discriminator"],
      discord_avatar_url: build_avatar_url(discord_data),
      discord_email: discord_data["email"],
      is_admin: is_admin,
      last_login_at: DateTime.utc_now()
    }, [
      :discord_id,
      :discord_username,
      :discord_discriminator,
      :discord_avatar_url,
      :discord_email,
      :is_admin,
      :last_login_at
    ])
    |> validate_required([:discord_id, :discord_username])
    |> unique_constraint(:discord_id)
  end

  defp build_avatar_url(%{"avatar" => nil}), do: nil
  defp build_avatar_url(%{"avatar" => avatar, "id" => user_id}) do
    "https://cdn.discordapp.com/avatars/#{user_id}/#{avatar}.png"
  end
  defp build_avatar_url(_), do: nil

  defp is_admin_discord_id?(discord_id) do
    admin_ids = 
      Application.get_env(:ace_app, :admin_discord_ids, "")
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == "" or &1 == "your_discord_user_id_here"))

    discord_id in admin_ids
  end
end