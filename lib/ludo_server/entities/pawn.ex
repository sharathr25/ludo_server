defmodule LudoServer.Pawn do
  defstruct [:no, :square_number, :group, :can_move]

  defimpl Jason.Encoder, for: LudoServer.Pawn do
    def encode(value, opts) do
      value
      |> Map.take([:no, :square_number, :group, :can_move])
      |> ProperCase.to_camel_case()
      |> Jason.Encode.map(opts)
    end
  end
end
