defmodule Bitcoin.Voyager.Handlers.Blockchain.TransactionHandler do
  alias Bitcoin.Voyager.Util
  use Bitcoin.Voyager.Handler

  def command, do: :blockchain_transaction

  def transform_args(%{hash: hash}) do
    Util.decode_hex(hash)
  end
  def transform_args(_params) do
    {:error, :invalid}
  end

  def transform_reply(reply) do
    tx = :libbitcoin.tx_decode(reply, :testnet)
    {:ok, %{transaction: tx}}
  end

  def cache_name, do: :transaction

  def cache_ttl, do: 0

  def cache_key([hash]), do: hash

end
