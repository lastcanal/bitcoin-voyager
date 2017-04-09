defmodule Bitcoin.Voyager.Handlers.Address.RecentHistoryHandler do
  alias Bitcoin.Voyager.Recent.Client, as: Recent
  alias Bitcoin.Voyager.Handlers.Address.History2Handler, as: Handler
  use Bitcoin.Voyager.Handler

  def command, do: fn(_client, address, _height, owner) ->
    ref = :erlang.make_ref()
    send(owner, {:libbitcoin_client, "address.recent_history", ref, Recent.history(address)})
    {:ok, ref}
  end

  defdelegate transform_args(parmas), to: Handler

  def transform_reply(reply) do
    {:ok, %{history: reply}}
  end

end

