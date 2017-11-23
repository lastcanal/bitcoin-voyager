defmodule Bitcoin.Voyager.Recent.Server do
  require Logger
  require Exquisite
  require Amnesia
  require Bitcoin.Voyager.Recent.History
  alias Bitcoin.Voyager.Recent.History
  use GenServer
  use Amnesia

  @prune_time (60 * 60 * 72)
  @fetch_transaction_timeout 5000

  defmodule State do
    defstruct []
  end

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    Logger.info "starting recent history server"
    true = register!
    Process.flag(:trap_exit, true)
    {:ok, %State{}}
  end

  def handle_info({"subscribe.block", _block}, state) do
    Bitcoin.Voyager.Recent.Client.prune(current_timestamp() - @prune_time)
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
    Logger.error("EXIT #{__MODULE__} #{reason}")
    {:noreply, state}
  end

  def terminate(_reason, _state) do
    true = unregister!
    :ok
  end

  def index_transaction(%{hash: hash, inputs: inputs, outputs: outputs} = tx) do
    row = %History{hash: hash, seen: current_timestamp()}
    Amnesia.Fragment.transaction do
      Enum.each Enum.with_index(inputs),  &index_spend(row, &1)
      Enum.each Enum.with_index(outputs), &index_output(row, &1)
    end
  end

  def index_spend(row, {%{address: address, previous_output: %{hash: hash, index: index}}, index}) do
    case History.where(hash: hash, index: index) do
      nil ->
        fetch_previous_output(row, hash, index)
      %History{address: address, value: value} ->
        History.write(%History{row |
          address: address, index: index, type: :spend, value: value})
    end
  end
  def index_spend(_row, {_txref, _index}) do
    :ok
  end

  def index_output(row, {%{address: address, value: value}, index}) do
    History.write(%History{row |
      address: address, index: index,
      value: value, type: :output
    })
  end
  def index_output(_row, {_txref, _index}) do
    :ok
  end

  def fetch_previous_output(row, hash, index) do
    client = :pg2.get_closest_pid(Bitcoin.Voyager.Client)
    prev_out_hash = Base.decode16!(hash, case: :lower)
    receiver = receive_transaction!(row, hash, index)
    Libbitcoin.Client.blockchain_transaction(client, prev_out_hash, receiver)
  end

  def receive_transaction!(row, hash, index) do
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
        {:libbitcoin_client_error, "blockchain.fetch_transaction", _ref, :not_found} ->
          {:error, :not_found}
        {:libbitcoin_client_error, "blockchain.fetch_transaction", _ref, error} ->
          Logger.error "#{__MODULE__} fetch transaction error #{error}"
          {:error, error}
      after
        @fetch_transaction_timeout ->
          Logger.error "#{__MODULE__} fetch transaction timeout"
          {:error, :timeout}
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
