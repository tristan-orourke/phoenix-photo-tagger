defmodule PhotoTagger.WeightedListTest do
	@moduledoc """
	Tests for the WeightedList module used for drift mode.
	"""

	use ExUnit.Case, async: true

	alias PhotoTagger.WeightedList

	describe "new/1" do
		test "creates weighted list from keyword list" do
			weighted_list = WeightedList.new([{:a, 1}, {:b, 2}])

			assert %WeightedList{} = weighted_list
			assert weighted_list.max == 3
			assert length(weighted_list.acc_list) == 2
		end

		test "raises ArgumentError for empty list" do
			assert_raise ArgumentError, "WeightedList cannot be initialized with an empty list", fn ->
				WeightedList.new([])
			end
		end

		test "accumulates weights correctly" do
			weighted_list = WeightedList.new([{:a, 2}, {:b, 3}, {:c, 5}])

			assert weighted_list.acc_list == [{:a, 2}, {:b, 5}, {:c, 10}]
			assert weighted_list.max == 10
		end
	end

	describe "sample/1" do
		test "returns item from list" do
			weighted_list = WeightedList.new([{:a, 1}, {:b, 2}, {:c, 3}])

			# Sample 20 times to verify all returns are valid items
			samples = for _ <- 1..20, do: WeightedList.sample(weighted_list)

			assert Enum.all?(samples, fn sample -> sample in [:a, :b, :c] end)
		end

		test "distribution respects weights over many samples" do
			# Create list where :a has weight 1 and :b has weight 9
			# Expected distribution: ~10% :a, ~90% :b
			weighted_list = WeightedList.new([{:a, 1}, {:b, 9}])

			# Sample 1000 times
			samples = for _ <- 1..1000, do: WeightedList.sample(weighted_list)

			# Count occurrences
			frequencies = Enum.frequencies(samples)
			a_count = Map.get(frequencies, :a, 0)
			b_count = Map.get(frequencies, :b, 0)

			# Calculate percentages
			a_percentage = a_count / 1000
			b_percentage = b_count / 1000

			# Allow some variance (roughly 10% ± 5% for :a, 90% ± 5% for :b)
			# With 1000 samples, we should be reasonably close to the expected distribution
			assert a_percentage >= 0.05 and a_percentage <= 0.15,
				"Expected :a to be ~10% but got #{a_percentage * 100}%"

			assert b_percentage >= 0.85 and b_percentage <= 0.95,
				"Expected :b to be ~90% but got #{b_percentage * 100}%"
		end
	end
end
