defmodule LudoServerWeb.Router do
  use LudoServerWeb, :router
  use Phoenix.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", LudoServerWeb do
    pipe_through :api

    get "/status", StatusController, :get_status
  end
end
