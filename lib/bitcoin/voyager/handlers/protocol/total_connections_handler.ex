defmodule Bitcoin.Voyager.Handlers.Protocol.TotalConnectionsHandler do
  use Bitcoin.Voyager.Handler

  def command, do: :total_connections

  def transform_args(_) do
    {:ok, []}
  end

  def transform_reply(connections) do
    {:ok, %{total_connections: connections}}
  end

end

