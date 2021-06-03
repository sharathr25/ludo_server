defmodule LudoServer.RoomServerTest do
  use ExUnit.Case, async: true
  import Mock

  alias LudoServerWeb.Endpoint
  alias LudoServer.RoomServer
  alias LudoServer.{Room, Player, Pawn}

  test "MOVE_PAWN" do
    room = %Room{
      room_id: "room_123",
      score: 6,
      current_player_seat: 1,
      players: [
        %Player{
          id: "player_123",
          seat: 1,
          pawns: [
            %Pawn{no: 1, square_number: 1, group: "HOME"},
            %Pawn{no: 2, square_number: 2, group: "HOME"},
            %Pawn{no: 3, square_number: 3, group: "HOME"},
            %Pawn{no: 4, square_number: 4, group: "HOME"}
          ]
        }
      ]
    }

    {:noreply, room} = RoomServer.handle_cast({:move_pawn, "player_123", 1}, room)

    updated_pawn = room |> Map.get(:players) |> hd |> Map.get(:pawns) |> hd

    assert %LudoServer.Pawn{group: "COMMUNITY", no: 1, square_number: 6} = updated_pawn
  end
end
