defmodule LudoServer.RoomServerSupervisor do
  use DynamicSupervisor
  alias LudoServer.RoomServer

  def start_link(_args) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def start_room_server(id) do
    spec = %{
      id: UUID.uuid1(),
      start: {RoomServer, :start_room, [id]},
      restart: :transient
    }

    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def init(_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
