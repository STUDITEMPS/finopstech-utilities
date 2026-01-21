defmodule Shared.Either do
  @moduledoc """
  Functional Either monad for handling success/error tuples.

  Either represents a value that can be one of two types:
  - `{:ok, value}` (right/success)
  - `{:error, reason}` (left/failure)

  ## Usage

      alias Shared.Either

      # Chain operations that might fail
      {:ok, user}
      |> Either.flat_map(&fetch_profile/1)
      |> Either.map(&format_name/1)

      # Traverse a list, stopping on first error
      user_ids
      |> Either.traverse(&fetch_user/1)

  """

  @type left :: {:error, any()}
  @type right(t) :: {:ok, t}
  @type either(t) :: left | right(t)

  # t und s sind als Parameter zu verstehen, die beliebige Typen annehmen
  # können. Insbesondere können t und s auch den selben Typ annehmen. Wichtig
  # ist nur, dass t und auch s in einer Spec immer nur einen Typ annehmen
  # können, sonst könnte man auch immer nur any() schreiben.
  @typep t :: any()
  @typep s :: any()

  @doc "Guard that checks if value is a left (error) tuple."
  defguard is_left?(value) when elem(value, 0) == :error

  @doc "Guard that checks if value is a right (ok) tuple."
  defguard is_right?(value) when elem(value, 0) == :ok

  @doc "Guard that checks if value is either a left or right tuple."
  defguard is_either?(value) when is_left?(value) or is_right?(value)

  @doc "Wraps a value in an ok tuple (right/success)."
  @spec return(t) :: right(t)
  def return(value), do: {:ok, value}

  @doc "Flattens a nested either into a single either."
  @spec flatten(either(either(t))) :: either(t)
  def flatten({:ok, maybe_value}), do: maybe_value
  def flatten({:error, error}), do: {:error, error}

  @doc "Applies a function to the value inside an ok tuple, wrapping the result."
  @spec map(either(t), (t -> s)) :: either(s)
  def map({:error, error}, _f), do: {:error, error}
  def map({:ok, value}, f), do: value |> f.() |> return()

  @doc "Maps a function over a list inside an ok tuple."
  @spec map_list(either(list(t)), (t -> s)) :: either(list(s))
  def map_list({:error, error}, _f), do: {:error, error}
  def map_list({:ok, list}, f), do: list |> Enum.map(f) |> return()

  @doc "Maps a function that returns an either, then flattens the result."
  @spec flat_map(either(t), (t -> either(s))) :: either(s)
  def flat_map(either, f), do: either |> map(f) |> flatten()

  @doc "Flat maps over a list inside an ok tuple, sequencing the results."
  @spec flat_map_list(either(list(t)), (t -> either(s))) :: either(list(s))
  def flat_map_list(either, f), do: either |> map_list(f) |> fold(fn error -> {:error, error} end, &sequence/1)

  @doc """
  Converts a list of eithers into an either of a list.

  Returns `{:ok, list}` if all elements are ok, or the first error encountered.
  """
  @spec sequence(list(either(t))) :: either(list(t))
  def sequence([]), do: return([])

  def sequence([{:ok, value} | tail]) do
    tail |> sequence() |> map(fn tail -> [value | tail] end)
  end

  def sequence([{:error, error} | _tail]), do: {:error, error}

  @doc """
  Applies a function to each element and collects the results.

  Stops at the first error and returns it.
  """
  @spec traverse(list(t), (t -> either(s))) :: either(list(s))
  def traverse([], _f), do: return([])

  def traverse([value | tail], f) do
    value |> f.() |> flat_map(fn value -> tail |> traverse(f) |> map(fn tail -> [value | tail] end) end)
  end

  @doc "Pattern matches on the either and applies the appropriate function."
  @spec fold(either(t), (any() -> s), (t -> s)) :: s
  def fold({:ok, value}, _if_error, if_ok), do: if_ok.(value)
  def fold({:error, error}, if_error, _if_ok), do: if_error.(error)

  @doc "Converts an either to `:ok` or `{:error, reason}`."
  @spec ok_or_error(either(t)) :: :ok | left()
  def ok_or_error(either), do: fold(either, fn error -> {:error, error} end, fn _ -> :ok end)
end
