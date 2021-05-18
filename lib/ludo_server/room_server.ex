defmodule LudoServer.RoomServer do
  use GenServer
  alias LudoServer.Room

  # Client
  def start_room() do
    room = %Room{room_token: UUID.uuid1(), players: []}
    {:ok, pid} = GenServer.start_link(__MODULE__, room, name: {:via, Swarm, room.room_token})
    {:ok, pid, room.room_token}
  end

  # Server (callbacks)
  @impl true
  def init(room) do
    {:ok, room}
  end
end
