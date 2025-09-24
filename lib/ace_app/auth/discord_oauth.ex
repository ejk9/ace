defmodule AceApp.Auth.DiscordOAuth do
  @moduledoc """
  Discord OAuth2 client for user authentication.
  """

  alias OAuth2.Client
  alias OAuth2.Strategy.AuthCode

  @doc """
  Creates an OAuth2 client configured for Discord.
  """
  def client do
    Client.new([
      strategy: AuthCode,
      client_id: get_client_id(),
      client_secret: get_client_secret(),
      redirect_uri: get_redirect_uri(),
      site: "https://discord.com/api",
      authorize_url: "https://discord.com/api/oauth2/authorize",
      token_url: "https://discord.com/api/oauth2/token"
    ])
  end

  @doc """
  Generates the Discord authorization URL with required scopes.
  """
  def authorize_url! do
    client()
    |> Client.authorize_url!(scope: "identify email")
  end

  @doc """
  Exchanges authorization code for access token and fetches user data.
  """
  def get_token_and_user!(code) do
    client = client()
    
    # Exchange code for token
    client = Client.get_token!(client, code: code)
    
    # Extract the actual access token from the JSON string
    actual_token = case Jason.decode(client.token.access_token) do
      {:ok, %{"access_token" => token}} -> token
      _ -> client.token.access_token  # fallback to original if parsing fails
    end
    
    # Create a new client with the properly extracted token
    fixed_client = %{client | token: %{client.token | access_token: actual_token}}
    
    # Fetch user information from Discord API
    user_response = OAuth2.Client.get!(fixed_client, "/users/@me")
    
    case user_response do
      %OAuth2.Response{status_code: 200, body: user_data} ->
        # Parse the JSON user data (similar to token parsing)
        parsed_user_data = case Jason.decode(user_data) do
          {:ok, data} -> data
          {:error, _} -> user_data  # fallback to original if parsing fails
        end
        
        {:ok, parsed_user_data}
        
      %OAuth2.Response{status_code: status, body: error} ->
        {:error, "Discord API error: #{status} - #{inspect(error)}"}
    end
  end

  defp get_client_id do
    case Application.get_env(:ace_app, :discord_oauth)[:client_id] do
      nil -> raise """
        Discord OAuth client_id is not configured.
        Update config/dev.exs with your Discord application credentials:
        
        config :ace_app, :discord_oauth,
          client_id: "your_discord_client_id_here",
          ...
        
        Or set the DISCORD_CLIENT_ID environment variable.
        Create a Discord application at https://discord.com/developers/applications
        """
      "your_discord_client_id_here" -> raise """
        Discord OAuth client_id is not configured.
        Replace "your_discord_client_id_here" in config/dev.exs with your actual Discord client ID
        from https://discord.com/developers/applications
        """
      client_id -> client_id
    end
  end

  defp get_client_secret do
    case Application.get_env(:ace_app, :discord_oauth)[:client_secret] do
      nil -> raise """
        Discord OAuth client_secret is not configured.
        Update config/dev.exs with your Discord application credentials.
        """
      "your_discord_client_secret_here" -> raise """
        Discord OAuth client_secret is not configured.
        Replace "your_discord_client_secret_here" in config/dev.exs with your actual Discord client secret
        from https://discord.com/developers/applications
        """
      client_secret -> client_secret
    end
  end

  defp get_redirect_uri do
    Application.get_env(:ace_app, :discord_oauth)[:redirect_uri] ||
      "http://localhost:4000/auth/discord/callback"
  end
end