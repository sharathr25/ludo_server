defmodule LudoServerWeb.RoomController do
  use LudoServerWeb, :controller

  def create_room(conn, %{"id" => id}) do
    {:ok, _pid, room_id} = LudoServer.RoomServerSupervisor.start_room_server(id)
    text(conn, room_id)
  end
end
