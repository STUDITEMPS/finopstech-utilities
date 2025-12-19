defmodule FinopstechUtilities.AsyncChunksTest do
  use ExUnit.Case, async: true

  import Enum, only: [to_list: 1]
  import FinopstechUtilities.AsyncChunks

  require Integer

  @schedulers System.schedulers_online()

  doctest FinopstechUtilities.AsyncChunks

  test "parallel processing" do
    times = Stream.cycle([5])
    stream = process(times, &sleep_for_each/1)
    {time, _results} = :timer.tc(Enum, :take, [stream, @schedulers], :millisecond)

    assert time in 50..150
  end

  test "chunk_size option" do
    times = Stream.cycle([5])
    stream = process(times, &sleep_for_each/1, chunk_size: 2)
    {time, _results} = :timer.tc(Enum, :take, [stream, @schedulers], :millisecond)

    assert time in 10..25

    stream = process(times, &sleep_for_each/1, chunk_size: 10)
    {time, _results} = :timer.tc(Enum, :take, [stream, @schedulers], :millisecond)

    assert time in 50..100

    # default is 10
    stream = process(times, &sleep_for_each/1)
    {time, _results} = :timer.tc(Enum, :take, [stream, @schedulers], :millisecond)

    assert time in 50..100
  end

  test "flatten option" do
    numbers = Stream.cycle(1..5)
    stream = process(numbers, &increment_each/1, flatten: true, chunk_size: 5)
    assert [2, 3, 4] = Enum.take(stream, 3)

    stream = process(numbers, &increment_each/1, flatten: false, chunk_size: 5)

    assert [
             [2, 3, 4, 5, 6],
             [2, 3, 4, 5, 6],
             [2, 3, 4, 5, 6]
           ] = Enum.take(stream, 3)

    # flatten: defaults to false
    stream = process(numbers, &increment_each/1, chunk_size: 5)

    assert [
             [2, 3, 4, 5, 6],
             [2, 3, 4, 5, 6],
             [2, 3, 4, 5, 6]
           ] = Enum.take(stream, 3)
  end

  test "ordered option" do
    stream = map([20, 30, 10], &sleep_and_return_time/1, chunk_size: 1, ordered: true)
    assert [20, 30, 10] = Enum.to_list(stream)

    stream = map([20, 30, 10], &sleep_and_return_time/1, chunk_size: 1, ordered: false)
    assert [10, 20, 30] = Enum.to_list(stream)

    stream = map([20, 30, 10], &sleep_and_return_time/1, chunk_size: 1)
    assert [20, 30, 10] = Enum.to_list(stream)
  end

  test "timeout option" do
    result =
      try do
        Enum.to_list(map([100], &sleep_and_return_time/1, timeout: 50))
      catch
        :exit, e -> {:exit, e}
      end

    assert {:exit, {:timeout, _}} = result
  end

  test "max_concurrency option" do
    stream = map([50, 50], &sleep_and_return_time/1, chunk_size: 1, max_concurrency: 1)
    {time, [50, 50]} = :timer.tc(Enum, :to_list, [stream], :millisecond)

    assert time in 100..130

    stream = map([50, 50], &sleep_and_return_time/1, chunk_size: 1, max_concurrency: 2)
    {time, [50, 50]} = :timer.tc(Enum, :to_list, [stream], :millisecond)

    assert time in 50..80
  end

  def async_sleep(times, opts \\ []) do
    times
    |> Stream.cycle()
    |> process(Enum, :map, [&sleep_and_return_time/1], opts)
  end

  def sleep_for_each(times), do: Enum.map(times, &sleep_and_return_time/1)
  def sleep_and_return_time(t), do: tap(t, &Process.sleep/1)

  def increment(num), do: num + 1
  def increment_each(nums), do: Enum.map(nums, &increment/1)

  def async_inc(numbers, opts \\ []) do
    numbers
    |> Stream.cycle()
    |> process(Enum, :map, [&(&1 + 1)], opts)
  end
end
