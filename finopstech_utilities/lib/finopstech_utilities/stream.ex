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
  Reports the progress of stream traversion to `:stdout`.

  ## Example

      1..100_000
      |> stream_progress(100_000)
      |> Stream.run()
  """
  @spec stream_progress(list() | map()) :: Enum.t()
  def stream_progress(enum), do: stream_progress(enum, :stdio)

  @spec stream_progress(Enum.t(), non_neg_integer() | IO.device()) :: Enum.t()
  def stream_progress(enum, total) when is_integer(total), do: stream_progress(enum, total, :stdio)

  def stream_progress(list, device) when is_list(list), do: stream_progress(list, length(list), device)

  def stream_progress(%{} = map, device) when not is_struct(map), do: stream_progress(map, map_size(map), device)

  @spec stream_progress(Enum.t(), non_neg_integer(), IO.device()) :: Enum.t()
  def stream_progress(enum, total, device) when is_integer(total) do
    digits = trunc(:math.log10(total)) + 1
    max_line_length = digits * 2 + 12

    stream_tap(
      enum,
      1,
      fn _, count ->
        progress = :erlang.float_to_binary(count / total * 100, decimals: 2)
        IO.write(device, "\r#{count}/#{total} | #{progress} %")
        count + 1
      end,
      fn _ -> IO.write(device, "\r#{String.duplicate(" ", max_line_length)}\r") end
    )
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
