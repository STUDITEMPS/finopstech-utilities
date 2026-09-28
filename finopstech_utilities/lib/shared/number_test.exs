defmodule Shared.NumberTest do
  use ExUnit.Case, async: true

  doctest Shared.Number

  describe "format/2" do
    for {number, fraction_digits, expected} <- [
          {1234.5, 2, "1.234,50"},
          {-1234.5, 2, "-1.234,50"},
          {1234, 2, "1.234,00"},
          {5, 2, "5,00"},
          {-5, 2, "-5,00"},
          {0, 2, "0,00"},
          {0.0, 2, "0,00"},
          {0, 0, "0"},
          {1000, 2, "1.000,00"},
          {-1_234_567, 0, "-1.234.567"},
          {23.0, 2, "23,00"},
          {23.333333333333332, 2, "23,33"},
          {0.30000000000000004, 2, "0,30"},
          {2.675, 2, "2,68"},
          {1.005, 2, "1,01"},
          {0.125, 2, "0,13"},
          {0.005, 2, "0,01"},
          {-0.005, 2, "-0,01"},
          {-0.001, 2, "-0,00"},
          {-0.004, 2, "-0,00"},
          {99.995, 2, "100,00"},
          {-99.995, 2, "-100,00"},
          {99_999.999, 2, "100.000,00"},
          {66.6666666, 0, "67"},
          {0.5, 0, "1"},
          {0.4, 0, "0"},
          {2.5, 0, "3"},
          {-2.5, 0, "-3"},
          {0.05, 1, "0,1"},
          {12.345, 1, "12,3"},
          {7.25, 3, "7,250"},
          {1_000_000_000, 2, "1.000.000.000,00"},
          {1.0e9, 2, "1.000.000.000,00"},
          {123_456_789.987, 2, "123.456.789,99"},
          {1.0e15, 2, "1.000.000.000.000.000,00"}
        ] do
      test "#{inspect(number)} with #{fraction_digits} fraction digits" do
        assert Shared.Number.format(unquote(number), unquote(fraction_digits)) == unquote(expected)
      end
    end

    test "defaults to two fraction digits" do
      assert Shared.Number.format(1234.5) == "1.234,50"
    end

    test "formats decimals" do
      assert Shared.Number.format(Decimal.new("1234.567")) == "1.234,57"
      assert Shared.Number.format(Decimal.new("5.00"), 1) == "5,0"
    end

    test "formats strings" do
      assert Shared.Number.format("12.345", 1) == "12,3"
    end

    test "returns nil for nil" do
      assert Shared.Number.format(nil, 2) == nil
    end
  end
end
