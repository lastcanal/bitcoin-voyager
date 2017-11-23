defmodule Bitcoin.Voyager.Handlers.Blockchain.History3Handler do
  alias Bitcoin.Voyager.Handlers.Address.HistoryHandler
  use Bitcoin.Voyager.Handler

  def command, do: :blockchain_history3

  def cache_name, do: :history2

  def transform_args(%{count: count} = args) when is_binary(count) do
    transform_args(%{args | count: String.to_integer(count)})
  end
  def transform_args(%{count: count, address: address}) when is_integer(count) do
    {:ok, [address, count]}
  end
  def transform_args(%{address: address}) do
    {:ok, [address, 20]}
  end
  def transform_args(_params) do
    {:error, :invalid}
  end

  def transform_reply(reply) do
    {:ok, %{history: Enum.map(reply, &format_row(&1))}}
  end

  def format_row(%{checksum: _, hash: hash} = row) do
    %{row | hash: Base.encode16(hash, case: :lower)}
  end
  def format_row(%{type: :output, hash: hash, index: index} = row) do
    checksum = :libbitcoin.spend_checksum(hash, index)
    row
      |> Map.put(:checksum, Integer.to_string(checksum, 16))
      |> format_row
  end
  def format_row(%{type: :spend, value: value} = row) do
    row
      |> Map.delete(:value)
      |> Map.put(:checksum, Integer.to_string(value, 16))
      |> format_row
  end

  def cache_key([address, count]) do
    "#{address}#{:binary.encode_unsigned(count)}"
  end

  defdelegate cache_ttl, to: HistoryHandler
  defdelegate cache_key(params), to: HistoryHandler
  defdelegate cache_serialize(value), to: HistoryHandler
  defdelegate cache_deserialize(value), to: HistoryHandler

end

