defmodule AceApp.Auth.UserSession do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_sessions" do
    field(:session_token, :string)
    field(:expires_at, :utc_datetime)

    belongs_to(:user, AceApp.Auth.User)

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc false
  def changeset(user_session, attrs) do
    user_session
    |> cast(attrs, [:session_token, :expires_at, :user_id])
    |> validate_required([:session_token, :expires_at, :user_id])
    |> unique_constraint(:session_token)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Creates a new session token that expires in 30 days
  """
  def create_session_changeset(user_session, user_id) do
    expires_at = DateTime.utc_now() |> DateTime.add(30, :day)
    session_token = generate_session_token()

    user_session
    |> cast(%{
      user_id: user_id,
      session_token: session_token,
      expires_at: expires_at
    }, [:user_id, :session_token, :expires_at])
    |> validate_required([:user_id, :session_token, :expires_at])
    |> unique_constraint(:session_token)
  end

  @doc """
  Generates a secure random session token
  """
  def generate_session_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  @doc """
  Checks if a session is expired
  """
  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end
end