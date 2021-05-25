defmodule LudoServer.Pawn do
  @derive {Jason.Encoder, only: [:no, :square]}
  defstruct [:no, :square]
end
