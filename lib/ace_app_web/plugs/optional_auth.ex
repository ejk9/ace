defmodule AceAppWeb.Plugs.OptionalAuth do
  @moduledoc """
  Plug to optionally authenticate users via session tokens.
  
  This plug checks for authentication but does not require it,
  allowing both anonymous and authenticated users to access the same routes.
  """
  
  import Plug.Conn
  alias AceApp.Auth

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :user_session_token) do
      nil ->
        # No session token, continue as anonymous user
        assign(conn, :current_user, nil)
        
      session_token ->
        case Auth.get_valid_user_session_by_token(session_token) do
          %{user: user} ->
            # Valid session found, assign current user
            assign(conn, :current_user, user)
            
          nil ->
            # Invalid or expired session, clear it and continue as anonymous
            conn
            |> delete_session(:user_session_token)
            |> assign(:current_user, nil)
        end
    end
  end
end