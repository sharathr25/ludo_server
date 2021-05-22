defmodule LudoServerWeb.RoomController do
  use LudoServerWeb, :controller

  def create_room(conn, _params) do
    {:ok, _pid, room_id} = LudoServer.RoomServerSupervisor.start_room_server()
    text(conn, room_id)
  end
end
