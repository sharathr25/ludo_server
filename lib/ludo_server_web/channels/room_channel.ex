alias LudoServer.RoomServer

defmodule LudoServerWeb.RoomChannel do
  use Phoenix.Channel

  def join("room:" <> _private_room_id, _params, socket) do
    {:ok, socket}
  end

  def handle_in("JOIN_GAME", %{"name" => name, "id" => id}, socket) do
    %{:topic => topic} = socket
    String.split(topic, ":") |> List.last() |> RoomServer.join_room(name, id)
    {:noreply, socket}
  end

  def handle_in("GET_GAME_STATE", _params, socket) do
    %{:topic => topic} = socket
    String.split(topic, ":") |> List.last() |> RoomServer.get_game_state()
    {:noreply, socket}
  end

  def handle_in("START_GAME", _params, socket) do
    %{:topic => topic} = socket
    String.split(topic, ":") |> List.last() |> RoomServer.start_game()
    {:noreply, socket}
  end
end
