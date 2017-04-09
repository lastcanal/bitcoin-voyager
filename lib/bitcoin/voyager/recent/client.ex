defmodule Bitcoin.Voyager.Recent.Client do
  require Logger
  require Exquisite
  require Amnesia
  require Bitcoin.Voyager.Recent.History
  alias Bitcoin.Voyager.Recent.History
  alias Bitcoin.Voyager.Recent.Server
  use GenServer
  use Amnesia

  def history(address, owner \\ self) do
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

