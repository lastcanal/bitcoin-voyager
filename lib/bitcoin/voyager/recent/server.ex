defmodule Bitcoin.Voyager.Recent.Server do
  require Logger
  require Exquisite
  require Amnesia
  require Bitcoin.Voyager.Recent.History
  alias Bitcoin.Voyager.Recent.History
  use GenServer
  use Amnesia

  @prune_time (60 * 60 * 72)

  defmodule State do
    defstruct []
  end

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    true = register!
    Process.flag(:trap_exit, true)
    {:ok, %State{}}
  end

  def handle_info({"subscribe.block", _block}, state) do
    spawn_link fn -> History.prune() end
    {:noreply, state}
  end
  def handle_info({"subscribe.transaction", transaction}, state) do
    index_transaction(transaction)
    {:noreply, state}
  end

  def handle_info({:EXIT, _from, :normal} = message, state) do
    {:noreply, state}
  end
  def handle_info({:EXIT, _from, reason} = message, state) do
    Logger.error("EXIT #{__MODULE__} #{_from} #{reason}")
    {:noreply, state}
  end

  def terminate(_reason, _state) do
    true = unregister!
    :ok
  end

  def index_transaction(transaction) do
    spawn_link fn ->
      row = %History{hash: transaction.hash, seen: current_timestamp()}
      Amnesia.Fragment.async do
        Enum.each Enum.with_index(transaction.inputs),  &index_spend(row, &1)
        Enum.each Enum.with_index(transaction.outputs), &index_output(row, &1)
      end
    end
  end

  def index_spend(row, {%{address: address, previous_output: previous_output}, index}) do
    History.write(%History{row |
      address: address, index: index, type: :spend, value: hash_previous_output(previous_output)
    })
  end
  def index_spend(row, {%{previous_output: %{hash: hash, index: index}}, index}) do
    case History.where(hash: hash, index: index) do
      nil ->
        fetch_previous_output(row, hash, index)
      %History{address: address, value: value} ->
        History.write(%History{row |
          address: address, index: index, type: :spend, value: value})
    end
  end

  def index_output(row, {%{address: address, value: value}, index}) do
    History.write(%History{row |
      address: address, index: index,
      value: value, type: :output
    })
  end
  def index_output(_row, {_output, _index}) do
    :ok
  end

  def fetch_previous_output(row, hash, index) do
    client = :pg2.get_closest_pid(Bitcoin.Voyager.Client)
    prev_out_hash = Base.decode16!(hash, case: :lower)
    pid = fetch_transaction(row, hash, index)
    Libbitcoin.Client.blockchain_transaction(client, prev_out_hash, pid)
  end

  def fetch_transaction(row, hash, index) do
    spawn_link fn->
      receive do
         {:libbitcoin_client, "blockchain.fetch_transaction", _ref, raw_transaction} ->
           %{outputs: outputs} = :libbitcoin.tx_decode(raw_transaction)
           %{address: address, value: value} = Enum.at(outputs, index)
           Amnesia.Fragment.async do
             History.write(%History{row |
              address: address, index: index, type: :spend,
              value: value
             })
            end
        _other ->
          :ok
      after
        1000 ->
          :ok
      end
    end
  end

  def register! do
    true = :gproc.reg({:p, :l, "subscribe.block"}, self)
    true = :gproc.reg({:p, :l, "subscribe.transaction"}, self)
  end

  def unregister! do
    true = :gproc.unreg({:p, :l, "subscribe.block"})
    true = :gproc.unreg({:p, :l, "subscribe.transaction"})
  end

  def hash_previous_output(%{hash: hash, index: index}) do
    hash
      |> Base.decode16!(case: :lower)
      |> Libbitcoin.Client.spend_checksum(index)
  end

  def current_timestamp do
    {mega, sec, _micro} = :os.timestamp()
    (mega * 1000000 + sec)
  end

end
