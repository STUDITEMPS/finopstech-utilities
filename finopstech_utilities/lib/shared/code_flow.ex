defmodule Shared.CodeFlow do
  @moduledoc """
  Utility functions for common control flow patterns with tuples.

  ## Usage

      import Shared.CodeFlow

      def my_function(value) do
        value
        |> do_something()
        |> ok()
      end

      def handle_info(:tick, state) do
        state
        |> update_state()
        |> noreply()
      end

  """

  @doc "Extracts the value from an `{:ok, value}` tuple."
  @spec success_value({:ok, any()}) :: any()
  def success_value({:ok, value}), do: value

  @doc "Returns the status atom from a `{status, value}` tuple."
  @spec status({atom(), any()}) :: atom()
  def status({status, _}), do: status

  @doc "Wraps a value in a `{:noreply, value}` tuple."
  @spec noreply(any()) :: {:noreply, any()}
  def noreply(value), do: {:noreply, value}

  @doc "Wraps a value in an `{:ok, value}` tuple."
  @spec ok(any()) :: {:ok, any()}
  def ok(value), do: {:ok, value}

  @doc """
  Checks if a result is successful or matches an expected error condition.

  Returns `:ok` if:
  - Result is `:ok`
  - Result is `{:ok, _}`
  - Result is `{:error, error}` and error matches the condition

  ## Examples

      iex> Shared.CodeFlow.successful_if(:ok, :any)
      :ok

      iex> Shared.CodeFlow.successful_if({:ok, "value"}, :any)
      :ok

      iex> Shared.CodeFlow.successful_if({:error, :not_found}, :not_found)
      :ok

      iex> Shared.CodeFlow.successful_if({:error, :not_found}, [:not_found, :expired])
      :ok

      iex> Shared.CodeFlow.successful_if({:error, :unauthorized}, :not_found)
      {:error, :unauthorized}

  """
  @spec successful_if(any(), atom() | [atom()]) :: :ok | {:error, any()}
  def successful_if(:ok = _result, _condition), do: :ok
  def successful_if({:ok, _} = _result, _condition), do: :ok
  def successful_if({:error, error} = _result, error), do: :ok

  def successful_if({:error, error}, conditions) when is_list(conditions) do
    if Enum.member?(conditions, error) do
      :ok
    else
      {:error, error}
    end
  end

  def successful_if(result, _error), do: result
end
