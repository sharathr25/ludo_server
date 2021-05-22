defmodule LudoServer.Room do
  @derive {Jason.Encoder, only: [:room_id, :players]}

  defstruct [:room_id, players: []]
end
