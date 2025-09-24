defmodule AceAppWeb.AuthController do
  use AceAppWeb, :controller

  alias AceApp.Auth
  alias AceApp.Auth.DiscordOAuth

  require Logger

  @doc """
  Redirects user to Discord OAuth authorization page.
  """
  def discord_redirect(conn, _params) do
    try do
      authorize_url = DiscordOAuth.authorize_url!()
      redirect(conn, external: authorize_url)
    rescue
      error ->
        Logger.error("Discord OAuth redirect error: #{inspect(error)}")
        
        conn
        |> put_flash(:error, "Discord authentication is not properly configured.")
        |> redirect(to: ~p"/")
    end
  end

  @doc """
  Handles Discord OAuth callback with authorization code.
  """
  def discord_callback(conn, %{"code" => code}) do
    try do
      case DiscordOAuth.get_token_and_user!(code) do
        {:ok, discord_user_data} ->
          handle_successful_discord_auth(conn, discord_user_data)
          
        {:error, reason} ->
          Logger.error("Discord OAuth token exchange error: #{reason}")
          
          conn
          |> put_flash(:error, "Failed to authenticate with Discord.")
          |> redirect(to: ~p"/")
      end
    rescue
      error ->
        Logger.error("Discord OAuth callback error: #{inspect(error)}")
        
        conn
        |> put_flash(:error, "Authentication failed. Please try again.")
        |> redirect(to: ~p"/")
    end
  end

  def discord_callback(conn, %{"error" => error, "error_description" => description}) do
    Logger.warning("Discord OAuth error: #{error} - #{description}")
    
    conn
    |> put_flash(:error, "Discord authentication was cancelled or failed.")
    |> redirect(to: ~p"/")
  end

  def discord_callback(conn, _params) do
    Logger.warning("Discord OAuth callback received without code or error")
    
    conn
    |> put_flash(:error, "Invalid authentication response from Discord.")
    |> redirect(to: ~p"/")
  end

  @doc """
  Logs out the current user by deleting their session.
  """
  def logout(conn, _params) do
    case get_session(conn, :user_session_token) do
      nil ->
        conn
        |> put_flash(:info, "You were already logged out.")
        |> redirect(to: ~p"/")
        
      session_token ->
        Auth.delete_user_session_by_token(session_token)
        
        conn
        |> delete_session(:user_session_token)
        |> put_flash(:info, "Logged out successfully.")
        |> redirect(to: ~p"/")
    end
  end

  defp handle_successful_discord_auth(conn, discord_user_data) do
    case Auth.get_or_create_user_from_discord(discord_user_data) do
      {:ok, user} ->
        case Auth.create_user_session(user.id) do
          {:ok, session} ->
            admin_message = if user.is_admin, do: " (Admin)", else: ""
            
            conn
            |> put_session(:user_session_token, session.session_token)
            |> put_flash(:info, "Welcome back, #{user.discord_username}!#{admin_message}")
            |> redirect(to: ~p"/drafts")
            
          {:error, changeset} ->
            Logger.error("Failed to create user session: #{inspect(changeset.errors)}")
            
            conn
            |> put_flash(:error, "Failed to create session. Please try again.")
            |> redirect(to: ~p"/")
        end
        
      {:error, changeset} ->
        Logger.error("Failed to create/update user: #{inspect(changeset.errors)}")
        
        conn
        |> put_flash(:error, "Failed to save user information. Please try again.")
        |> redirect(to: ~p"/")
    end
  end
end