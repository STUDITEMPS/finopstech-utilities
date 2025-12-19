defmodule FinopstechUtilities.Stream do
  @moduledoc """
  Defines some utilities to help working with streams

  The functions of this module are intended to be imported.

      import FinopstechUtilities.Stream
  """

  @doc """
  Counts the number of elements in the stream while processing and invokes the
  given funktionen with the total number.

  ## Example

      stream_count(
        Stream.repeatedly(fn -> :rand.uniform(5000) end),
        &Logger.info("Generated \#{&1} numbers.")
      ) |> Stream.take(10) |> Stream.run()
  """
  @spec stream_count(Enum.t(), (non_neg_integer() -> any())) :: Enum.t()
  def stream_count(stream, fun) when is_function(fun, 1) do
    stream_tap(stream, 0, fn _, c -> c + 1 end, fun)
  end

  @doc """
  This function accumulates a value and let you do something with is after the
  stream has finished processing. The Stream content itselve is left unchanged.
  This is usefull for gathering some statistics along the way.

  ## Example

      stream_tap(
        Stream.repeatedly(fn -> :rand.uniform(5000) end),
        %{},
        fn n, acc ->
          acc
          |> Map.update(:count, 1, & &1 + 1)
          |> Map.update(:min, n, &min(&1, n))
          |> Map.update(:max, n, &max(&1, n))
        end,
        &Logger.info("Generated \#{&1.count} numbers, with \#{&1.max} as the maximum and \#{&1.min} as the minimum.")
      ) |> Stream.take(10) |> Stream.run()
  """
  @spec stream_tap(Enum.t(), (-> term()), (term() -> term()), (term() -> term())) :: Enum.t()
  def stream_tap(stream, acc, reducer, after_fun) when not is_function(acc),
    do: stream_tap(stream, fn -> acc end, reducer, after_fun)

  def stream_tap(stream, start_fun, reducer, after_fun)
      when is_function(start_fun, 0) and is_function(reducer, 2) and is_function(after_fun, 1),
      do: Stream.transform(stream, start_fun, &{[&1], reducer.(&1, &2)}, after_fun)
end
