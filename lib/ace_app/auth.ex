defmodule AceApp.Auth do
  @moduledoc """
  The Auth context for managing user authentication via Discord OAuth.
  """

  import Ecto.Query, warn: false
  alias AceApp.Repo
  alias AceApp.Auth.{User, UserSession}
  alias AceApp.Drafts

  ## Users

  @doc """
  Gets a single user by ID.
  """
  def get_user(id) do
    Repo.get(User, id)
  end

  @doc """
  Gets a single user by Discord ID.
  """
  def get_user_by_discord_id(discord_id) do
    Repo.get_by(User, discord_id: discord_id)
  end

  @doc """
  Creates or updates a user from Discord OAuth data.
  """
  def get_or_create_user_from_discord(discord_data) do
    case get_user_by_discord_id(discord_data["id"]) do
      nil ->
        # Create new user
        %User{}
        |> User.discord_changeset(discord_data)
        |> Repo.insert()
        
      existing_user ->
        # Update existing user with latest Discord data
        existing_user
        |> User.discord_changeset(discord_data)
        |> Repo.update()
    end
  end

  @doc """
  Lists all admin users.
  """
  def list_admin_users do
    User
    |> where([u], u.is_admin == true)
    |> Repo.all()
  end

  ## User Sessions

  @doc """
  Creates a new user session.
  """
  def create_user_session(user_id) do
    %UserSession{}
    |> UserSession.create_session_changeset(user_id)
    |> Repo.insert()
  end

  @doc """
  Gets a user session by token, including the associated user.
  """
  def get_user_session_by_token(token) do
    UserSession
    |> where([s], s.session_token == ^token)
    |> preload(:user)
    |> Repo.one()
  end

  @doc """
  Gets a valid (non-expired) user session by token.
  """
  def get_valid_user_session_by_token(token) do
    case get_user_session_by_token(token) do
      %UserSession{} = session ->
        if UserSession.expired?(session) do
          delete_user_session(session)
          nil
        else
          session
        end
      nil ->
        nil
    end
  end

  @doc """
  Deletes a user session.
  """
  def delete_user_session(%UserSession{} = session) do
    Repo.delete(session)
  end

  @doc """
  Deletes a user session by token.
  """
  def delete_user_session_by_token(token) do
    case get_user_session_by_token(token) do
      %UserSession{} = session -> delete_user_session(session)
      nil -> {:ok, nil}
    end
  end

  @doc """
  Deletes all expired sessions (cleanup task).
  """
  def delete_expired_sessions do
    now = DateTime.utc_now()
    
    UserSession
    |> where([s], s.expires_at < ^now)
    |> Repo.delete_all()
  end

  ## Draft Access Control

  @doc """
  Lists drafts accessible to a user based on enhanced access control.
  
  - Anonymous users: Public drafts only
  - Regular authenticated users: Their own drafts (public + private) + other users' public drafts
  - Admin users: All drafts (public + private)
  """
  def list_accessible_drafts(user \\ nil)

  def list_accessible_drafts(nil) do
    # Anonymous users see only public drafts
    Drafts.list_public_drafts()
  end

  def list_accessible_drafts(%User{is_admin: true}) do
    # Admin users see all drafts
    Drafts.list_drafts()
  end

  def list_accessible_drafts(%User{id: user_id}) do
    # Regular users see their own drafts + other public drafts
    Drafts.list_accessible_drafts_for_user(user_id)
  end

  @doc """
  Checks if a user can access a specific draft based on enhanced access control.
  """
  def can_access_draft?(user, draft)

  def can_access_draft?(nil, %{visibility: :public}) do
    # Anonymous users can access public drafts
    true
  end

  def can_access_draft?(nil, %{visibility: :private}) do
    # Anonymous users cannot access private drafts
    false
  end

  def can_access_draft?(nil, %{user_id: nil}) do
    # Legacy drafts without owners are accessible (backward compatibility)
    true
  end

  def can_access_draft?(%User{is_admin: true}, _draft) do
    # Admin users can access any draft
    true
  end

  def can_access_draft?(%User{id: user_id}, %{user_id: draft_user_id}) do
    # Users can access their own drafts (regardless of visibility)
    user_id == draft_user_id
  end

  def can_access_draft?(%User{}, %{visibility: :public}) do
    # Authenticated users can access public drafts
    true
  end

  def can_access_draft?(%User{}, %{visibility: :private}) do
    # Authenticated users cannot access other users' private drafts
    false
  end

  def can_access_draft?(_user, %{user_id: nil}) do
    # Legacy drafts without owners are accessible (backward compatibility)
    true
  end

  @doc """
  Associates a draft with a user (called when authenticated user creates draft).
  """
  def assign_draft_to_user(draft_id, user_id) do
    draft = Drafts.get_draft!(draft_id)
    
    draft
    |> Ecto.Changeset.change(user_id: user_id)
    |> Repo.update()
  end
end