defmodule LudoServer.RoomServer do
  use GenServer
  alias LudoServer.{Room, Player, Pawn}
  alias LudoServerWeb.Endpoint

  @start_squares_for_seats %{1 => 0, 2 => 13, 3 => 26, 4 => 39}
  @end_squares_for_seats %{1 => 51, 2 => 12, 3 => 25, 4 => 38}
  @end_square_of_board 52
  @required_score_to_move_from_home 6
  @max_home_column_score 6
  @starting_pawns [
    %Pawn{no: 1, position_number: 1, group: "HOME"},
    %Pawn{no: 2, position_number: 2, group: "HOME"},
    %Pawn{no: 3, position_number: 3, group: "HOME"},
    %Pawn{no: 4, position_number: 4, group: "HOME"}
  ]
  @safe_squares [1, 14, 27, 40]

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

  def capture_pawn(room_id, updated_player_id, updated_pawn) do
    GenServer.cast({:via, :swarm, room_id}, {:capture_pawn, updated_player_id, updated_pawn})
  end

  # Server (callbacks) ----------------
  @impl true
  def init(room) do
    {:ok, room}
  end

  @impl true
  def handle_cast(
        {:join_room, name, id},
        %Room{room_id: room_id, players: existing_players} = state
      ) do
    updated_state =
      state
      |> add_player(name, id, Enum.any?(existing_players, fn p -> p.id == id end))

    Endpoint.broadcast!("room:#{room_id}", "PLAYER_JOINED_NOTIFY", updated_state)

    {:noreply, updated_state}
  end

  @impl true
  def handle_cast({:get_game_state}, %Room{room_id: room_id} = state) do
    Endpoint.broadcast!("room:#{room_id}", "GET_GAME_STATE_NOTIFY", state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:start_game}, %Room{players: existing_players} = state) do
    updated_state = state |> start_game(length(existing_players) > 1)
    {:noreply, updated_state}
  end

  @impl true
  def handle_cast({:roll_dice, player_id}, %Room{room_id: room_id} = state) do
    updated_state =
      state
      |> update_score
      |> update_movable_pawns(player_id)
      |> maybe_player_can_move

    Endpoint.broadcast!("room:#{room_id}", "ROLL_DICE_NOTIFY", updated_state)

    {:noreply, updated_state}
  end

  @impl true
  def handle_cast({:move_pawn, player_id, pawn_no}, %Room{room_id: room_id} = state) do
    updated_state =
      state
      |> update_players_pawn(player_id, pawn_no)
      |> update_players_rank(player_id)
      |> proceed_or_end_game

    Endpoint.broadcast!("room:#{room_id}", "MOVE_PAWN_NOTIFY", updated_state)

    {:noreply, updated_state}
  end

  @impl true
  def handle_cast({:capture_pawn, updated_player_id, updated_pawn}, state) do
    updated_state =
      state
      |> capture_and_update_players(updated_player_id, updated_pawn)

    {:noreply, updated_state}
  end

  # private functions ------------------------
  defp maybe_player_can_move(
         %Room{players: players, current_player_seat: current_player_seat} = state
       ) do
    is_there_a_movable_pawn =
      players
      |> Enum.find(fn p -> p.seat == current_player_seat end)
      |> Map.get(:pawns)
      |> Enum.any?(fn p -> p.can_move end)

    update_action_to_take(state, is_there_a_movable_pawn)
  end

  defp update_action_to_take(
         %Room{players: players, current_player_seat: current_player_seat} = state,
         _is_there_a_movable_pawn = false
       ) do
    players_still_need_to_play = players |> Enum.filter(fn p -> p.rank == 0 end)

    %Room{
      state
      | current_player_seat:
          get_next_player(current_player_seat, players_still_need_to_play).seat,
        action_to_take: "ROLL_DICE"
    }
  end

  defp update_action_to_take(state, _is_there_a_movable_pawn = true) do
    %Room{
      state
      | action_to_take: "MOVE_PAWN"
    }
  end

  defp add_player(state, _name, _id, _players_already_exists = true) do
    state
  end

  defp add_player(
         %Room{players: existing_players} = state,
         name,
         id,
         _players_already_exists = false
       ) do
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
                pawns: @starting_pawns
              }
            ]
    }
  end

  defp start_game(%Room{room_id: room_id} = state, _more_than_one_player_available = true) do
    updated_state = %Room{
      state
      | game_status: "ON_GOING",
        current_player_seat: Enum.at(Map.get(state, :players), 0).seat,
        action_to_take: "ROLL_DICE"
    }

    Endpoint.broadcast!("room:#{room_id}", "START_GAME_NOTIFY", updated_state)

    updated_state
  end

  defp start_game(
         %Room{room_id: room_id} = state,
         _more_than_one_player_available = false
       ) do
    Endpoint.broadcast!("room:#{room_id}", "START_GAME_ERROR", %{reason: "NOT_ENOUGH_PLAYERS"})
    state
  end

  defp get_next_player(current_player_seat, players) do
    next_player_index =
      players
      |> Enum.find_index(fn p ->
        p.seat == current_player_seat
      end)
      |> Kernel.+(1)
      |> rem(length(players))

    Enum.at(players, next_player_index)
  end

  defp proceed_or_end_game(%Room{players: updated_players} = state) do
    players_still_need_to_play = updated_players |> Enum.filter(fn p -> p.rank == 0 end)
    proceed_or_end_game(state, players_still_need_to_play)
  end

  defp proceed_or_end_game(state, _players_still_need_to_play = []) do
    %Room{
      state
      | game_status: "GAME_OVER",
        current_player_seat: nil,
        action_to_take: nil
    }
  end

  defp proceed_or_end_game(
         %Room{current_player_seat: current_player_seat} = state,
         players_still_need_to_play
       ) do
    %Room{
      state
      | action_to_take: "ROLL_DICE",
        current_player_seat: get_next_player(current_player_seat, players_still_need_to_play).seat
    }
  end

  defp maybe_update_pawn(%Pawn{group: "HOME"} = pawn, seat, score) do
    %Pawn{
      pawn
      | position_number: score + @start_squares_for_seats[seat],
        group: "COMMUNITY"
    }
  end

  defp maybe_update_pawn(
         %Pawn{group: "HOME_COLUMN", position_number: position_number} = pawn,
         _seat,
         score
       ) do
    cond do
      score + position_number < @max_home_column_score ->
        %Pawn{
          pawn
          | position_number: rem(score + position_number, @end_square_of_board)
        }

      score + position_number == @max_home_column_score ->
        %Pawn{
          pawn
          | position_number: 1,
            group: "WIN_TRIANGLE"
        }

      true ->
        pawn
    end
  end

  defp maybe_update_pawn(
         %Pawn{group: "COMMUNITY", position_number: position_number} = pawn,
         seat,
         score
       ) do
    cond do
      position_number == @end_squares_for_seats[seat] and
          score == @max_home_column_score ->
        %Pawn{
          pawn
          | position_number: 1,
            group: "WIN_TRIANGLE"
        }

      position_number < @end_squares_for_seats[seat] and
          score + position_number > @end_squares_for_seats[seat] ->
        %Pawn{
          pawn
          | position_number:
              score + position_number -
                @end_squares_for_seats[seat],
            group: "HOME_COLUMN"
        }

      true ->
        %Pawn{
          pawn
          | position_number:
              get_position_number(rem(score + position_number, @end_square_of_board))
        }
    end
  end

  defp maybe_update_pawn(pawn, _, _) do
    pawn
  end

  defp get_position_number(_current_position_number = 0) do
    @end_square_of_board
  end

  defp get_position_number(current_position_number) do
    current_position_number
  end

  defp update_score(state) do
    nos_on_dice = [1, 2, 3, 4, 5, 6]
    score = Enum.random(nos_on_dice)
    %Room{state | score: score}
  end

  defp update_movable_pawns(%Room{score: score, players: players} = state, player_id) do
    updated_players =
      players
      |> Enum.map(fn p ->
        if p.id === player_id do
          update_movable_pawns(p, score)
        else
          p
        end
      end)

    %Room{state | players: updated_players}
  end

  defp update_movable_pawns(%Player{pawns: pawns} = player, score) do
    updated_pawns =
      pawns
      |> Enum.map(fn p -> update_if_pawn_can_move(p, score) end)

    %Player{player | pawns: updated_pawns}
  end

  defp update_if_pawn_can_move(
         %Pawn{group: "HOME"} = pawn,
         _score = @required_score_to_move_from_home
       ) do
    %Pawn{pawn | can_move: true}
  end

  defp update_if_pawn_can_move(
         %Pawn{group: "HOME_COLUMN", position_number: position_number} = pawn,
         score
       )
       when score + position_number <= @max_home_column_score do
    %Pawn{pawn | can_move: true}
  end

  defp update_if_pawn_can_move(%Pawn{group: "COMMUNITY"} = pawn, _score) do
    %Pawn{pawn | can_move: true}
  end

  defp update_if_pawn_can_move(pawn, nil) do
    %Pawn{pawn | can_move: false}
  end

  defp update_if_pawn_can_move(pawn, _) do
    %Pawn{pawn | can_move: false}
  end

  defp update_players_pawn(
         %Room{score: score, players: players, room_id: room_id} = state,
         player_id,
         pawn_no
       ) do
    updated_players =
      players
      |> Enum.map(fn p ->
        if p.id == player_id do
          update_player_pawns(p, pawn_no, score, player_id, room_id)
        else
          p
        end
      end)

    %Room{state | players: updated_players}
  end

  defp update_player_pawns(
         %Player{:pawns => pawns, :seat => seat} = player,
         pawn_no,
         score,
         player_id,
         room_id
       ) do
    updated_pawns =
      pawns
      |> Enum.map(fn p ->
        if p.no == pawn_no do
          pawn = maybe_update_pawn(p, seat, score)

          if p.position_number != pawn.position_number or p.group != pawn.group do
            capture_pawn(room_id, player_id, pawn)
          end

          pawn
        else
          p
        end
      end)
      |> Enum.map(fn p -> %Pawn{p | can_move: false} end)

    %Player{player | pawns: updated_pawns}
  end

  defp update_players_rank(%Room{players: players} = state, player_id) do
    max_rank = players |> Enum.map(fn p -> p.rank end) |> Enum.max()

    updated_players =
      players
      |> Enum.map(fn p ->
        if p.id == player_id do
          update_player_rank(p, max_rank)
        else
          p
        end
      end)

    %Room{state | players: updated_players}
  end

  defp update_player_rank(%Player{pawns: pawns} = player, max_rank) do
    maybe_update_rank(
      player,
      Enum.all?(pawns, fn p -> p.group == "WIN_TRIANGLE" end),
      max_rank
    )
  end

  defp maybe_update_rank(%Player{rank: 0} = player, _won = true, max_rank) do
    %Player{player | rank: max_rank + 1}
  end

  defp maybe_update_rank(player, _won, _max_rank) do
    player
  end

  defp capture_and_update_players(
         %Room{players: players, room_id: room_id} = state,
         updated_player_id,
         %Pawn{group: group, position_number: position_number} = updated_pawn
       ) do
    if Enum.member?(@safe_squares, position_number) or group != "COMMUNITY" do
      state
    else
      updated_players =
        players
        |> Enum.map(fn p ->
          if p.id == updated_player_id do
            p
          else
            maybe_capture_pawn(p, updated_pawn, room_id)
          end
        end)

      %{state | players: updated_players}
    end
  end

  defp maybe_capture_pawn(%Player{pawns: pawns} = player, updated_pawn, room_id) do
    captured_pawns =
      pawns
      |> Enum.filter(fn p ->
        p.position_number == updated_pawn.position_number and p.group == updated_pawn.group
      end)
      |> Enum.map(fn p ->
        %Pawn{p | position_number: get_open_home_position_number(pawns), group: "HOME"}
      end)

    non_captured_pawns =
      pawns |> Enum.filter(fn p -> p.position_number != updated_pawn.position_number end)

    updated_pawns = (captured_pawns ++ non_captured_pawns) |> Enum.sort(&(&2 >= &1))

    if length(captured_pawns) == 1 do
      Endpoint.broadcast!("room:#{room_id}", "PAWN_CAPTURE_NOTIFY", hd(captured_pawns))
      %{player | pawns: updated_pawns}
    else
      player
    end
  end

  defp get_open_home_position_number(pawns) do
    occupied_homes =
      pawns
      |> Enum.filter(fn p -> p.group == "HOME" end)
      |> Enum.map(fn p -> p.position_number end)

    ([1, 2, 3, 4] -- occupied_homes) |> hd()
  end
end
