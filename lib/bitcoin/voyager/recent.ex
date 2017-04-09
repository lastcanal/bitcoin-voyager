use Amnesia

defdatabase Bitcoin.Voyager.Recent do

  deftable History,
           [:address, :hash, :index, :value, :type, :seen],
           [type: :bag] do

    @type t :: %History{address: String.t, hash: String.t,
      index: non_neg_integer(), value: non_neg_integer(),
      seen: non_neg_integer(), type: :output | :spend}

    def history(address, owner \\ self) do
      Amnesia.Fragment.sync do
        History.match(address: address)
          |> Amnesia.Selection.values
          |> Enum.map(&Map.from_struct(&1))
      end
    end

    def prune do
      Amnesia.Fragment.async do
        History.where(seen < current_timestamp() - @prune_time)
          |> Amnesia.Selection.values
          |> Enum.each(&History.delete(&1))
      end
    end

  end

end
