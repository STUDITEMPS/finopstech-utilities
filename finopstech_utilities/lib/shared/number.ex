if Code.ensure_loaded?(Cldr.Number) do
  defmodule Shared.Number do
    @moduledoc """
    German number formatting with a dot as thousands separator and a comma as
    decimal separator.

    Requires the optional dependency `ex_cldr_numbers`.
    """

    @type number_like :: integer() | float() | Decimal.t() | String.t()

    @doc """
    Formats a number with thousands separators and `fraction_digits` decimal places,
    rounding half up.

        iex> Shared.Number.format(1234.5)
        "1.234,50"

        iex> Shared.Number.format(-1_234_567, 0)
        "-1.234.567"

        iex> Shared.Number.format(nil)
        nil
    """
    @spec format(number_like() | nil, non_neg_integer()) :: String.t() | nil
    def format(number, fraction_digits \\ 2)
    def format(nil, _fraction_digits), do: nil

    def format(number, fraction_digits) when is_integer(fraction_digits) and fraction_digits >= 0 do
      number
      |> to_decimal()
      |> Shared.Number.Cldr.Number.to_string!(fractional_digits: fraction_digits, rounding_mode: :half_up)
    end

    # CLDR doesn't round floats exactly (e.g. 0.005 becomes "0,00"); going through the
    # shortest decimal representation of the float gives correct half-up rounding.
    defp to_decimal(number) when is_float(number), do: Decimal.from_float(number)
    defp to_decimal(number) when is_binary(number), do: Decimal.new(number)
    defp to_decimal(number), do: number
  end
end
