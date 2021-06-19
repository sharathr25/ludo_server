defmodule LudoServer.Player do
  @derive {Jason.Encoder, only: [:id, :name, :pawns, :seat, :rank]}
  defstruct [:id, :name, :seat, pawns: [], rank: 0]
end
