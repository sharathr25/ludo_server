defmodule LudoServer.RoomServer do
  use GenServer
  alias LudoServer.{Room, Player, Pawn}
  alias LudoServerWeb.Endpoint

  # Client
  def start_room(id) do
    room = %Room{room_id: UUID.uuid1(), players: [], host_id: id}
    {:ok, pid} = GenServer.start_link(__MODULE__, room, name: {:via, Swarm, room.room_id})
    {:ok, pid, room.room_id}
  end

  def join_room(room_id, name, id) do
    GenServer.cast({:via, :swarm, room_id}, {:join_room, name, id})
  end

  def get_game_state(room_id) do
    GenServer.cast({:via, :swarm, room_id}, {:get_game_state})
  end

  # Server (callbacks)
  @impl true
  def init(room) do
    {:ok, room}
  end

  @impl true
  def handle_cast({:join_room, name, id}, state) do
    room_id = Map.get(state, :room_id)
    existing_players = Map.get(state, :players)

    updated_state =
      add_player(state, name, id, Enum.any?(existing_players, fn p -> p.id == id end))

    Endpoint.broadcast!("room:#{room_id}", "PLAYER_JOINED_NOTIFY", updated_state)

    {:noreply, updated_state}
  end

  @impl true
  def handle_cast({:get_game_state}, state) do
    room_id = Map.get(state, :room_id)
    Endpoint.broadcast!("room:#{room_id}", "GET_GAME_STATE_NOTIFY", state)
    {:noreply, state}
  end

  defp add_player(state, _name, _id, true) do
    state
  end

  defp add_player(state, name, id, false) do
    existing_players = Map.get(state, :players)
    no_of_existing_players = length(existing_players)
    seat = no_of_existing_players + 1

    %Room{
      state
      | players:
          existing_players ++
            [
              %Player{
                name: name,
                seat: seat,
                id: id,
                pawns: [
                  %Pawn{no: 1, square: "H#{seat}HS1"},
                  %Pawn{no: 2, square: "H#{seat}HS2"},
                  %Pawn{no: 3, square: "H#{seat}HS3"},
                  %Pawn{no: 4, square: "H#{seat}HS4"}
                ]
              }
            ]
    }
  end
end
