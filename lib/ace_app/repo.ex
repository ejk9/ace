defmodule AceApp.Repo do
  use Ecto.Repo,
    otp_app: :ace_app,
    adapter: Ecto.Adapters.Postgres
end
