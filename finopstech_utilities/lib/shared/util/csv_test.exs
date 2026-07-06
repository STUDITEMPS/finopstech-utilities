defmodule Shared.Util.CSVTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Shared.Util.CSV

  test "bildet jedes Element ab und leitet die Header aus den Map-Schlüsseln ab" do
    format_csv_result =
      format_csv [%{key: 1}, %{key: 2}] do
        %{key: value} ->
          %{"OUTPUT" => value * 10}
      end

    zeilen = Enum.to_list(format_csv_result)

    assert zeilen == ["OUTPUT\r\n", "10\r\n", "20\r\n"]
  end

  test "übernimmt mehrere Header in Reihenfolge der Map" do
    format_csv_result =
      format_csv [%{a: 1, b: 2}] do
        %{a: a, b: b} ->
          %{"A" => a, "B" => b}
      end

    zeilen = Enum.to_list(format_csv_result)

    assert zeilen == ["A,B\r\n", "1,2\r\n"]
  end

  test "reicht zusätzliche Optionen an CSV.encode/2 durch" do
    format_csv_result =
      format_csv [%{a: 1, b: 2}], separator: ?; do
        %{a: a, b: b} ->
          %{"A" => a, "B" => b}
      end

    zeilen = Enum.to_list(format_csv_result)

    assert zeilen == ["A;B\r\n", "1;2\r\n"]
  end

  test "leitet den kodierten Stream per Stream.into ins :into-Ziel" do
    pfad = Path.join(System.tmp_dir!(), "format_csv_#{System.unique_integer([:positive])}.csv")
    on_exit(fn -> File.rm(pfad) end)

    format_csv_result =
      format_csv [%{key: 1}, %{key: 2}], into: File.stream!(pfad) do
        %{key: value} ->
          %{"OUTPUT" => value}
      end

    Stream.run(format_csv_result)
    assert File.read!(pfad) == "OUTPUT\r\n1\r\n2\r\n"
  end

  test "wirft ArgumentError, wenn :headers in den Optionen angegeben werden" do
    assert_raise ArgumentError, ~r/:headers.*automatisch/s, fn ->
      Code.eval_quoted(
        quote do
          import Shared.Util.CSV

          format_csv [%{key: 1}], headers: ["X"] do
            %{key: value} ->
              %{"OUTPUT" => value}
          end
        end
      )
    end
  end
end
