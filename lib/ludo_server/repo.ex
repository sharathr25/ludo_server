defmodule LudoServer.Repo do
  use Ecto.Repo,
    otp_app: :ludo_server,
    adapter: Ecto.Adapters.Postgres
end
