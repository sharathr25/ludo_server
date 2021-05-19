defmodule LudoServerWeb.RoomChannel do
  use Phoenix.Channel

  def join("room:" <> private_room_id, _params, socket) do
    {:ok, socket}
  end
end
