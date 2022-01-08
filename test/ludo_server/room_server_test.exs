defmodule LudoServer.RoomServerTest do
  use ExUnit.Case, async: true

  alias LudoServer.RoomServer
  alias LudoServer.{Room, Player, Pawn}

  test "MOVE_PAWN for the 1st time" do
    room = %Room{
      room_id: "room_123",
      score: 6,
      current_player_seat: 1,
      players: [
        %Player{
          id: "player_123",
          seat: 1,
          pawns: [
            %Pawn{no: 1, position_number: 1, group: "HOME"},
            %Pawn{no: 2, position_number: 2, group: "HOME"},
            %Pawn{no: 3, position_number: 3, group: "HOME"},
            %Pawn{no: 4, position_number: 4, group: "HOME"}
          ]
        }
      ]
    }

    {:noreply, room} = RoomServer.handle_cast({:move_pawn, "player_123", 1}, room)

    updated_pawn = room |> Map.get(:players) |> hd |> Map.get(:pawns) |> hd

    assert %LudoServer.Pawn{group: "COMMUNITY", no: 1, position_number: 6} = updated_pawn
  end

  test "MOVE_PAWN from community square to home column when score increases player last square" do
    room = %Room{
      room_id: "room_123",
      score: 6,
      current_player_seat: 1,
      players: [
        %Player{
          id: "player_123",
          seat: 1,
          pawns: [
            %Pawn{no: 1, position_number: 50, group: "COMMUNITY"}
          ]
        }
      ]
    }

    {:noreply, room} = RoomServer.handle_cast({:move_pawn, "player_123", 1}, room)

    updated_pawn = room |> Map.get(:players) |> hd |> Map.get(:pawns) |> hd

    assert %LudoServer.Pawn{group: "HOME_COLUMN", no: 1, position_number: 5} = updated_pawn
  end

  test "MOVE_PAWN from community square to community square when score increases last square" do
    room = %Room{
      room_id: "room_123",
      score: 6,
      current_player_seat: 2,
      players: [
        %Player{
          id: "player_123",
          seat: 2,
          pawns: [
            %Pawn{no: 1, position_number: 50, group: "COMMUNITY"}
          ]
        }
      ]
    }

    {:noreply, room} = RoomServer.handle_cast({:move_pawn, "player_123", 1}, room)

    updated_pawn = room |> Map.get(:players) |> hd |> Map.get(:pawns) |> hd

    assert %LudoServer.Pawn{group: "COMMUNITY", no: 1, position_number: 4} = updated_pawn
  end

  test "MOVE_PAWN to a square which already have another player pawn if the square is not safe square" do
    room = %Room{
      room_id: "room_123",
      score: 6,
      current_player_seat: 1,
      players: [
        %Player{
          id: "player_123",
          seat: 1,
          pawns: [
            %Pawn{no: 1, position_number: 30, group: "COMMUNITY"}
          ]
        },
        %Player{
          id: "player_346",
          seat: 2,
          pawns: [
            %Pawn{no: 1, position_number: 30, group: "COMMUNITY"},
            %Pawn{no: 2, position_number: 1, group: "HOME"}
          ]
        }
      ]
    }

    {:noreply, room} =
      RoomServer.handle_cast(
        {:capture_pawn, "player_123", %Pawn{no: 1, position_number: 30, group: "COMMUNITY"}},
        room
      )

    captured_pawn =
      room
      |> Map.get(:players)
      |> List.last()
      |> Map.get(:pawns)
      |> hd

    assert %LudoServer.Pawn{group: "HOME", no: 1, position_number: 2} = captured_pawn
  end
end
