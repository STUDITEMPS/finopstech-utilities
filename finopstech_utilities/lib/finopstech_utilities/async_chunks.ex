defmodule FinopstechUtilities.AsyncChunks do
  @moduledoc """
  Functions to asynchronously process an enumerable in chunks.

  The basic functionality provide `process/3` and `process/5`. They will invoke
  the given function on chunks of size provided by the option `chunk_size`.

  Except for `reduce/2` - `reduce/4`, the functions of this module can be used
  as drop-in replacements for the corresponding functions of the `Enum` module.
  But keep in mind that behaviour might change when functions have side effects.

  ## Options

  All functions accept the options `:chunk_size`, `:flatten` and `t:Task.async_stream_option()`.
  The following documents the most relevant. For the rest consult the docs of `Task.async_stream/5`.

  * `:chunk_size` Default: `10` - The size of each chunk. Since each chunk is processed
    in a separate task, increasing the `chunk_size` might increase the processing time for
    each chunk, thus risking to exceed the `:timeout`. Therefore adjust the `chunk_size`
    and `timeout` to your needs.
  * `:flatten` - Whether to flatten the results into a single list or value. The
    default value and the exact behaviour depends on the function used.
  * `:timeout` Default: `5000` - The timeout for each chunk.
  * `:max_concurrency` Default: `System.schedulers_online()` - The maximum number of
    concurrent tasks.
  * `:ordered` Default: `true` - Whether the order of the results should be preserved.

  > [!NOTE] Keep in mind that async processing indroduces additional overhead.
  > So it is recommended to stick to the `Enum` module if viable.
  """
  require Integer

  @default_chunk_size 10

  @type opts :: [option()]
  @type option ::
          {:chunk_size, pos_integer()}
          | {:flatten, boolean()}
          | Task.async_stream_option()

  @doc """
  Maps an enumerable asynchronously in chunks.

  Same as `process(enumerable, Enum, :map, [function], opts)``.

  ## Example

      iex> to_list map([1, 2, 3], & &1 * 2)
      [2, 4, 6]
  """
  @spec map(Enum.t(), (term() -> term()), opts()) :: Enum.t()
  def map(enumerable, function, opts \\ []),
    do: process(enumerable, Enum, :map, [function], Keyword.put_new(opts, :flatten, true))

  @doc """
  Maps an enumerable asynchronously in chunks and flattens the result.

  Same as `process(enumerable, Enum, :flat_map, [function], opts)``.

  ## Example

      iex> to_list flat_map([1, 2, 3], &([&1, &1 * 2]))
      [1, 2, 2, 4, 3, 6]
  """
  @spec flat_map(Enum.t(), (term() -> term()), opts()) :: Enum.t()
  def flat_map(enumerable, function, opts \\ []),
    do: process(enumerable, Enum, :flat_map, [function], Keyword.put_new(opts, :flatten, true))

  @doc """
  Filters an enumerable asynchronously in chunks.

  Same as `process(enumerable, Enum, :filter, [function], opts)``.

  ## Example

      iex> to_list filter(1..9, &Integer.is_odd/1)
      [1, 3, 5, 7, 9]
  """
  @spec filter(Enum.t(), (term() -> term()), opts()) :: Enum.t()
  def filter(enumerable, function, opts \\ []),
    do: process(enumerable, Enum, :filter, [function], Keyword.put_new(opts, :flatten, true))

  @doc """
  Rejects elements from an enumerable asynchronously in chunks.

  Same as `process(enumerable, Enum, :reject, [function], opts)``.

  ## Example

      iex> to_list reject(1..9, &Integer.is_odd/1)
      [2, 4, 6, 8]
  """
  @spec reject(Enum.t(), (term() -> term()), opts()) :: Enum.t()
  def reject(enumerable, function, opts \\ []),
    do: process(enumerable, Enum, :reject, [function], Keyword.put_new(opts, :flatten, true))

  @doc """
  Reduces over an enumerable asynchronously in chunks.

  > [!NOTE] This function processes the enumerable in chunks and reduces each
  > chunk separately and does **not** combine the results.
  > Combine the results using `Enum.reduce/3` if you need a single accumulated
  > value.

  Same as `process(enumerable, Enum, :reduce, [function], opts)``.

  ## Example

      iex> to_list reduce(1..10, &Kernel.+/2, chunk_size: 2)
      [3, 7, 11, 15, 19]

      iex> to_list reduce(1..10, 1, &Kernel.+/2, chunk_size: 2)
      [4, 8, 12, 16, 20]

      iex> (reduce(1..10, 1, &Kernel.+/2, chunk_size: 2)
      ...> |> Enum.reduce(&Kernel.+/2))
      60
  """
  @spec reduce(Enum.t(), (term(), term() -> term()), opts()) :: Enum.t()
  def reduce(enumerable, function, opts \\ [])

  def reduce(enumerable, function, opts) when is_list(opts), do: process(enumerable, Enum, :reduce, [function], opts)

  @spec reduce(Enum.t(), term(), (term(), term() -> term()), opts()) :: Enum.t()
  def reduce(enumerable, acc, function) when is_function(function), do: reduce(enumerable, acc, function, [])

  def reduce(enumerable, acc, function, opts), do: process(enumerable, Enum, :reduce, [acc, function], opts)

  @doc """
  map_joins an enumerable processing it with async chunks.

  By default, the results are "flattened" into a single string.
  Use `flatten: false` to keep the list of joined chunks.

  Same as `process(enumerable, Enum, :map_join, [function], opts)``.

  ## Example

      iex> map_join(?a..?z, &to_string([&1]))
      "abcdefghijklmnopqrstuvwxyz"

      iex> to_list map_join(?a..?z, &to_string([&1]), flatten: false)
      ["abcdefghij", "klmnopqrst", "uvwxyz"]
  """
  @spec map_join(Enum.t(), (term() -> term()), opts()) :: Enum.t()
  def map_join(enumerable, function), do: map_join(enumerable, "", function, [])

  def map_join(enumerable, function, opts) when is_list(opts), do: map_join(enumerable, "", function, opts)

  @spec map_join(Enum.t(), term(), (term() -> term()), opts()) :: String.t() | Enum.t(String.t())
  def map_join(enumerable, joiner, function) when is_function(function), do: map_join(enumerable, joiner, function, [])

  def map_join(enumerable, joiner, function, opts) do
    {flatten, opts} = Keyword.pop(opts, :flatten, true)
    args = [joiner, function]

    with stream when flatten <- process(enumerable, Enum, :map_join, args, opts),
         do: Enum.join(stream, joiner)
  end

  @doc """
  Tests if function returns true forall elements of an enumerable processing it with async chunks.

  By default, the results are "flattened" into a single boolean.
  Use `flatten: false` to keep the list of combined chunks.

  Same as `process(enumerable, Enum, :all?, [function], opts)``.

  ## Example

      iex> all?([1, 5, 9, 15, 99], &Integer.is_odd(&1), chunk_size: 2)
      true

      iex> all?([1, 5, 8, 15, 99], &Integer.is_odd(&1), chunk_size: 2)
      false

      iex> to_list all?([1, 5, 8, 15, 99], &Integer.is_odd(&1), chunk_size: 2, flatten: false)
      [true, false, true]
  """
  @spec all?(Enum.t(), (term() -> boolean()), opts()) :: boolean() | Enum.t(boolean())
  def all?(enumerable, function, opts \\ []) do
    {flatten, opts} = Keyword.pop(opts, :flatten, true)

    with stream when flatten <- process(enumerable, Enum, :all?, [function], opts),
         do: Enum.all?(stream)
  end

  @doc """
  tests if function returns true for any element of an enumerable processing it with async chunks.

  By default, the results are "flattened" into a single boolean.
  Use `flatten: false` to keep the list of combined chunks.

  Same as `process(enumerable, Enum, :any?, [function], opts)``.

  ## Example

      iex> any?([2, 4, 6, 8], &Integer.is_odd(&1), chunk_size: 2)
      false

      iex> any?([3, 4, 6, 8], &Integer.is_odd(&1), chunk_size: 2)
      true

      iex> to_list any?([3, 4, 6, 8], &Integer.is_odd(&1), chunk_size: 2, flatten: false)
      [true, false]
  """
  @spec any?(Enum.t(), (term() -> boolean()), opts()) :: boolean() | Enum.t(boolean())
  def any?(enumerable, function, opts \\ []) do
    {flatten, opts} = Keyword.pop(opts, :flatten, true)

    with stream when flatten <- process(enumerable, Enum, :any?, [function], opts),
         do: Enum.any?(stream)
  end

  @doc """
  Applies the given function to chunks of the enumerable asynchronously.

  The Enumerable is split into chunks of size `chunk_size` and each chunk is
  processed asynchronously with `Task.async_stream/5`.

  This function will return a stream containing the results of each function call.
  If a list is returned for each chunk, the result will be a nested list.
  Use `flatten: true` to flatten the results into a single list.

  ## Options

  * `:chunk_size` - The size of each chunk. Defaults to `10`.
  * `:flatten` - Whether to flatten the results into a single list. Defaults to `false`.

  The function accepts also `t:Task.async_stream_option/0` options, and passes
  them to `Task.async_stream/5`.

  ## Example

      iex> to_list process(1..20, Kernel, :length, [])
      [10, 10]

      iex> to_list process(1..20, Enum, :map, [&Kernel.div(&1, 2)], chunk_size: 5)
      [[0, 1, 1, 2, 2], [3, 3, 4, 4, 5], [5, 6, 6, 7, 7], [8, 8, 9, 9, 10]]

      iex> to_list process(1..20, Enum, :map, [&Kernel.div(&1, 2)], flatten: true)
      [0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10]
  """
  @spec process(Enum.t(), module(), atom(), list(), opts()) :: Enum.t()
  def process(enumerable, module, function, args, opts \\ []) do
    {chunk_size, opts} = Keyword.pop(opts, :chunk_size, @default_chunk_size)
    {flatten, opts} = Keyword.pop(opts, :flatten, false)

    stream =
      enumerable
      |> Stream.chunk_every(chunk_size)
      |> Task.async_stream(module, function, args, opts)

    if flatten,
      do: Stream.flat_map(stream, &unwrap_async_result/1),
      else: Stream.map(stream, &unwrap_async_result/1)
  end

  @doc """
  Applies the given function to chunks of the enumerable asynchronously.

  Like `process/5` but accepts functions of arity 1.
  See `process/5` for options.

  ## Example

      iex> to_list process(?A..?Z, &to_string/1)  
      ["ABCDEFGHIJ", "KLMNOPQRST", "UVWXYZ"]
  """
  @spec process(Enum.t(), (term() -> term()), opts()) :: Enum.t()
  def process(enumerable, function, opts \\ []) do
    {chunk_size, opts} = Keyword.pop(opts, :chunk_size, @default_chunk_size)
    {flatten, opts} = Keyword.pop(opts, :flatten, false)

    stream =
      enumerable
      |> Stream.chunk_every(chunk_size)
      |> Task.async_stream(function, opts)

    if flatten,
      do: Stream.flat_map(stream, &unwrap_async_result/1),
      else: Stream.map(stream, &unwrap_async_result/1)
  end

  defp unwrap_async_result({:ok, result}), do: result
end
