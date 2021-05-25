defmodule LudoServer.Room do
  @derive {Jason.Encoder, only: [:room_id, :players, :host_id]}

  defstruct [:room_id, :host_id, players: []]
end
