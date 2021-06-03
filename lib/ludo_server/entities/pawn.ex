defmodule LudoServer.Pawn do
  defstruct [:no, :square_number, :group]

  defimpl Jason.Encoder, for: LudoServer.Pawn do
    def encode(value, opts) do
      value
      |> Map.take([:no, :square_number, :group])
      |> ProperCase.to_camel_case()
      |> Jason.Encode.map(opts)
    end
  end
end
