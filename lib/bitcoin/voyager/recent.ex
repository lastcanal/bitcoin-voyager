use Amnesia

defdatabase Bitcoin.Voyager.Recent do

  deftable History,
           [:address, :hash, :index, :value, :type, :seen],
           [type: :bag] do

    @type t :: %History{address: String.t, hash: String.t,
      index: non_neg_integer(), value: non_neg_integer(),
      seen: non_neg_integer(), type: :output | :spend}

  end

end
