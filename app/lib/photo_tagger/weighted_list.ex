defmodule PhotoTagger.WeightedList do
  defstruct [:acc_list, :max]

  def new([]) do
    raise ArgumentError, "WeightedList cannot be initialized with an empty list"
  end

  # Initialize a weighted list where each item is a tuple of the form {value, weight}
  def new(kw_list) do
    # TODO: Might want to verify it is sorted lowest to highest weight
    acc_list = Enum.scan(kw_list, fn {k, w}, {_, w_sum} -> {k, w + w_sum} end)
    {_, max} = List.last(acc_list)
    %__MODULE__{acc_list: acc_list, max: max}
  end

  def sample(%__MODULE__{acc_list: acc_list, max: max}) do
    rand_value = Enum.random(1..max)

    Enum.find_value(acc_list, fn
      {k, w} when rand_value <= w -> k
      _ -> false
    end)
  end
end
