defmodule LudoServer.RoomServer do
  use GenServer
  alias LudoServer.{Room, Player, Pawn}
  alias LudoServerWeb.Endpoint

  @start_squares_for_seats %{1 => 0, 2 => 13, 3 => 26, 4 => 39}
  @end_squares_for_seats %{1 => 51, 2 => 12, 3 => 25, 4 => 38}
  @end_square_of_board 52

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

  def roll_dice(room_id, player_id) do
    GenServer.cast({:via, :swarm, room_id}, {:roll_dice, player_id})
  end

  def move_pawn(room_id, player_id, pawn_no) do
    GenServer.cast({:via, :swarm, room_id}, {:move_pawn, player_id, pawn_no})
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
    # updated_state = start_game(state, room_id, length(existing_players) > 1)
    updated_state = start_game(state, room_id, true)
    {:noreply, updated_state}
  end

  @impl true
  def handle_cast({:roll_dice, player_id}, state) do
    nos_on_dice = [6]
    room_id = Map.get(state, :room_id)
    score = Enum.random(nos_on_dice)
    players = Map.get(state, :players)

    pawns_that_can_move =
      Enum.find(players, nil, fn p -> p.id == player_id end)
      |> Map.get(:pawns)
      |> Enum.filter(fn p ->
        (p.group == "HOME" and score == 6) or
          (p.group === "HOME_COLUMN" and score + p.square_number <= 6) or
          (p.group != "HOME" and p.group != "HOME_COLUMN" and p.group != "WIN_TRIANGLE")
      end)
      |> Enum.map(fn p -> p.no end)

    updated_state = %Room{
      maybe_player_can_move(state, length(pawns_that_can_move) > 0, pawns_that_can_move)
      | score: score
    }

    Endpoint.broadcast!("room:#{room_id}", "ROLL_DICE_NOTIFY", updated_state)

    {:noreply, updated_state}
  end

  @impl true
  def handle_cast({:move_pawn, player_id, pawn_no}, state) do
    room_id = Map.get(state, :room_id)
    score = Map.get(state, :score)
    players = Map.get(state, :players)
    player = players |> Enum.find(nil, fn p -> p.id == player_id end)
    other_players = players |> Enum.filter(fn p -> p.id != player_id end)
    %Player{:pawns => pawns, :seat => seat} = player

    updated_pawns =
      pawns
      |> Enum.map(fn p -> maybe_update_pawn(p, seat, score, p.no == pawn_no) end)

    updated_player =
      %Player{player | pawns: updated_pawns}
      |> maybe_update_rank(
        Enum.all?(updated_pawns, fn p -> p.group == "WIN_TRIANGLE" end),
        Enum.map(players, fn p -> p.rank end) |> Enum.max()
      )

    updated_players = other_players ++ [updated_player]

    players_still_need_to_play = updated_players |> Enum.filter(fn p -> p.rank == 0 end)

    updated_state = proceed_or_end_game(players_still_need_to_play, updated_players, state)

    Endpoint.broadcast!("room:#{room_id}", "MOVE_PAWN_NOTIFY", updated_state)

    {:noreply, updated_state}
  end

  # private functions ------------------------
  defp maybe_player_can_move(state, _is_there_pawns_to_move = true, pawns_that_can_move) do
    %Room{
      state
      | pawns_that_can_move: pawns_that_can_move,
        action_to_take: "MOVE_PAWN"
    }
  end

  defp maybe_player_can_move(state, _is_there_pawns_to_move = false, _pawns_that_can_move) do
    current_player_seat = Map.get(state, :current_player_seat)
    players_still_need_to_play = Map.get(state, :players) |> Enum.filter(fn p -> p.rank == 0 end)

    %Room{
      state
      | current_player_seat:
          get_next_player(current_player_seat, players_still_need_to_play).seat,
        action_to_take: "ROLL_DICE"
    }
  end

  defp add_player(state, _name, _id, true) do
    state
  end

  defp add_player(state, name, id, false) do
    existing_players = Map.get(state, :players)
    no_of_existing_players = length(existing_players)
    seat = no_of_existing_players + 4

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
                  %Pawn{no: 1, square_number: 1, group: "HOME"},
                  %Pawn{no: 2, square_number: 2, group: "HOME"},
                  %Pawn{no: 3, square_number: 3, group: "HOME"},
                  %Pawn{no: 4, square_number: 4, group: "HOME"}
                ]
              }
            ]
    }
  end

  defp start_game(state, room_id, _more_than_one_player_available = true) do
    updated_state = %Room{
      state
      | game_status: "ON_GOING",
        current_player_seat: Enum.at(Map.get(state, :players), 0).seat,
        action_to_take: "ROLL_DICE"
    }

    Endpoint.broadcast!("room:#{room_id}", "START_GAME_NOTIFY", updated_state)

    updated_state
  end

  defp start_game(state, room_id, _more_than_one_player_available = false) do
    Endpoint.broadcast!("room:#{room_id}", "START_GAME_ERROR", %{reason: "NOT_ENOUGH_PLAYERS"})
    state
  end

  defp get_next_player(current_player_seat, players) do
    players
    |> Enum.at(
      rem(
        Enum.find_index(
          players,
          fn p ->
            p.seat == current_player_seat
          end
        ) + 1,
        length(players)
      )
    )
  end

  defp proceed_or_end_game(_players_still_need_to_play = [], players, state) do
    %Room{
      state
      | players: players,
        game_status: "GAME_OVER",
        pawns_that_can_move: [],
        current_player_seat: nil,
        action_to_take: nil
    }
  end

  defp proceed_or_end_game(players_still_need_to_play, players, state) do
    current_player_seat = Map.get(state, :current_player_seat)

    %Room{
      state
      | players: players,
        action_to_take: "ROLL_DICE",
        pawns_that_can_move: [],
        current_player_seat: get_next_player(current_player_seat, players_still_need_to_play).seat
    }
  end

  defp maybe_update_rank(%Player{rank: 0} = player, _won = true, max_rank) do
    %Player{player | rank: max_rank + 1}
  end

  defp maybe_update_rank(player, _won, _max_rank) do
    player
  end

  defp maybe_update_pawn(p, seat, score, _need_to_move = true) do
    cond do
      p.group == "HOME" ->
        %Pawn{
          p
          | square_number: score + @start_squares_for_seats[seat],
            group: "COMMUNITY"
        }

      p.group == "COMMUNITY" and seat == 1 and
          score + p.square_number > @end_squares_for_seats[seat] ->
        %Pawn{
          p
          | square_number: score + p.square_number - @end_squares_for_seats[seat],
            group: "HOME_COLUMN"
        }

      p.group == "COMMUNITY" and
        p.square_number <= @end_squares_for_seats[seat] and
          score + p.square_number > @end_squares_for_seats[seat] ->
        %Pawn{
          p
          | square_number:
              rem(score + p.square_number, @end_square_of_board) -
                @end_squares_for_seats[seat],
            group: "HOME_COLUMN"
        }

      p.group == "HOME_COLUMN" and score + p.square_number < 6 ->
        %Pawn{
          p
          | square_number: rem(score + p.square_number, @end_square_of_board)
        }

      p.group == "HOME_COLUMN" and score + p.square_number == 6 ->
        %Pawn{
          p
          | square_number: 1,
            group: "WIN_TRIANGLE"
        }

      p.group == "COMMUNITY" ->
        %Pawn{
          p
          | square_number: get_square_number(rem(score + p.square_number, @end_square_of_board))
        }

      true ->
        p
    end
  end

  defp maybe_update_pawn(pawn, _seat, _score, _need_to_move = false) do
    pawn
  end

  defp get_square_number(_current_square_number = 0) do
    @end_square_of_board
  end

  defp get_square_number(current_square_number) do
    current_square_number
  end
end
