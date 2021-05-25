defmodule LudoServer.Player do
  @derive {Jason.Encoder, only: [:id, :name, :pawns, :seat]}
  defstruct [:id, :name, :seat, pawns: []]
end
