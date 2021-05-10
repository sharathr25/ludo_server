defmodule LudoServerWeb.StatusController do
  use LudoServerWeb, :controller

  def get_status(conn, _params) do
    text(conn, "UP!")
  end
end
