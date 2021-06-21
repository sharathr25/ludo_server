defmodule LudoServer.Room do
  defstruct [
    :room_id,
    :host_id,
    :game_status,
    :current_player_seat,
    :action_to_take,
    :score,
    players: []
  ]

  defimpl Jason.Encoder, for: LudoServer.Room do
    def encode(value, opts) do
      value
      |> Map.take([
        :room_id,
        :players,
        :host_id,
        :game_status,
        :score,
        :current_player_seat,
        :action_to_take
      ])
      |> ProperCase.to_camel_case()
      |> Jason.Encode.map(opts)
    end
  end
end
