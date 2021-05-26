defmodule LudoServer.Room do
  defstruct [:room_id, :host_id, players: []]

  defimpl Jason.Encoder, for: LudoServer.Room do
    def encode(value, opts) do
      value
      |> Map.take([:room_id, :players, :host_id])
      |> ProperCase.to_camel_case()
      |> Jason.Encode.map(opts)
    end
  end
end
