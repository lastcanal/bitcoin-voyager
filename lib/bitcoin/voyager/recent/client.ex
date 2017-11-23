defmodule Bitcoin.Voyager.Recent.Client do
  require Logger
  require Exquisite
  require Amnesia
  require Bitcoin.Voyager.Recent.History
  alias Bitcoin.Voyager.Recent.History
  alias Bitcoin.Voyager.Recent.Server
  use GenServer
  use Amnesia

  def since_offset(offset) do
    since(Server.current_timestamp() - offset)
  end

  def since(time) do
    Amnesia.Fragment.async do
      History.where(seen > time)
        |> Amnesia.Selection.values
        |> Enum.map(&Map.from_struct(&1))
    end
  end

  def history(address) do
    Amnesia.Fragment.sync do
      History.match(address: address)
        |> Amnesia.Selection.values
        |> Enum.map(&Map.from_struct(&1))
    end
  end

  def prune(prune_time) do
    Amnesia.Fragment.async do
      History.where(seen < prune_time)
        |> Amnesia.Selection.values
        |> Enum.each(&History.delete(&1))
    end
  end

end

