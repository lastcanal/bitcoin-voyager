defmodule Bitcoin.Voyager.Handlers.TransactionPool.Validate2Handler do
  alias Bitcoin.Voyager.Util
  use Bitcoin.Voyager.Handler

  def command, do: :transaction_pool_validate2

  def transform_args(%{transaction: transaction}) do
    Util.decode_hex(transaction)
  end
  def transform_args(_params) do
    {:error, :invalid}
  end

  def transform_reply(reply) do
    {:ok, %{status: reply}}
  end

end


