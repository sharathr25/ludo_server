defmodule LudoServer.RoomServer do
  use GenServer
  alias LudoServer.{Room, Player, Pawn}
  alias LudoServerWeb.Endpoint

  # Client -------------------------
  def start_room(id) do
    room = %Room{room_id: UUID.uuid1(), players: [], host_id: id, game_status: "CREATED"}
    {:ok, pid} = GenServer.start_link(__MODULE__, room, name: {:via, Swarm, room.room_id})
    {:ok, pid, room.room_id}
  end

  def join_room(room_id, name, id) do
    GenServer.cast({:via, :swarm, room_id}, {:join_room, name, id})
  end

  def get_game_state(room_id) do
    GenServer.cast({:via, :swarm, room_id}, {:get_game_state})
  end

  def start_game(room_id) do
    GenServer.cast({:via, :swarm, room_id}, {:start_game})
  end

  # Server (callbacks) ----------------
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

  @impl true
  def handle_cast({:start_game}, state) do
    room_id = Map.get(state, :room_id)
    existing_players = Map.get(state, :players)
    updated_state = start_game(state, room_id, length(existing_players) > 1)
    {:noreply, updated_state}
  end

  # private functions ------------------------
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

  defp start_game(state, room_id, _more_than_one_player_available = true) do
    players = Map.get(state, :players)
    player_in_seat_1 = Enum.filter(players, fn p -> p.seat == 1 end) |> List.first()
    id_of_player_in_seat_1 = Map.get(player_in_seat_1, :id)

    updated_state = %Room{
      state
      | game_status: "ON_GOING",
        current_player_id: id_of_player_in_seat_1,
        action_to_take: "ROLL_DICE"
    }

    Endpoint.broadcast!("room:#{room_id}", "START_GAME_NOTIFY", updated_state)

    updated_state
  end

  defp start_game(state, room_id, _more_than_one_player_available = false) do
    Endpoint.broadcast!("room:#{room_id}", "START_GAME_ERROR", %{reason: "NOT_ENOUGH_PLAYERS"})
    state
  end
end
