defmodule Shared.Util.CSV do
  @moduledoc """
  Wandelt ein `Enumerable` deklarativ in einen CSV-Stream um.

  Das Makro `format_csv/2` nimmt ein Enumerable und einen Block, der jedes Element
  auf eine Map abbildet. Die Schlüssel dieser Map werden automatisch zu den
  CSV-Headern und in genau dieser Reihenfolge ausgegeben.

  ## Verwendung

      import Shared.Util.CSV

      format_csv enumerable do
        %{key: value} ->
          %{"OUTPUT" => format(value)}
      end

  Das obige ist äquivalent zu:

      enumerable
      |> Stream.map(fn %{key: value} ->
        %{"OUTPUT" => format(value)}
      end)
      |> CSV.encode(headers: ["OUTPUT"])

  Die Header werden aus den Schlüsseln der zurückgegebenen Map abgeleitet, damit
  `CSV.encode/2` pro Zeile die passenden Werte findet.

  ## Optionen

  Alle weiteren Optionen werden unverändert an `CSV.encode/2` durchgereicht. So
  lässt sich z. B. ein anderes Trennzeichen setzen:

      format_csv enumerable, separator: ?; do
        %{key: value} ->
          %{"OUTPUT" => format(value)}
      end

  wird zu:

      enumerable
      |> Stream.map(fn %{key: value} ->
        %{"OUTPUT" => format(value)}
      end)
      |> CSV.encode(headers: ["OUTPUT"], separator: ?;)

  Die Sonderoption `:into` wird nicht an `CSV.encode/2` durchgereicht, sondern
  hängt ein `Stream.into/2` an, um den Stream direkt in ein Ziel zu schreiben:

      format_csv enumerable, into: File.stream!("out.csv") do
        %{key: value} ->
          %{"OUTPUT" => format(value)}
      end

  wird zu:

      enumerable
      |> Stream.map(fn %{key: value} ->
        %{"OUTPUT" => format(value)}
      end)
      |> CSV.encode(headers: ["OUTPUT"])
      |> Stream.into(File.stream!("out.csv"))

  Setzt `:csv` als Abhängigkeit voraus.
  """

  @doc """
  Bildet `enumerable` per `Stream.map/2` mit dem übergebenen Block ab und
  kodiert das Ergebnis mit `CSV.encode/2`.

  Die `:headers`-Option wird aus den Map-Schlüsseln des Blocks abgeleitet.

  `csv_opts` wird an `CSV.encode/2` durchgereicht. Die Sonderoption `:into`
  wird abgezweigt: ist sie gesetzt, wird der kodierte Stream per
  `Stream.into/2` in das angegebene Ziel (z. B. einen `File.stream!/1`)
  geleitet.
  """
  defmacro format_csv(enumerable, csv_opts \\ [], do: clauses) do
    if Keyword.has_key?(csv_opts, :headers) do
      raise ArgumentError,
            "format_csv leitet die :headers automatisch aus den Map-Schlüsseln des " <>
              "Blocks ab; gib sie nicht zusätzlich in den Optionen an."
    end

    headers = extract_headers(clauses)
    {into, csv_opts} = Keyword.pop(csv_opts, :into)

    encoded =
      quote do
        unquote(enumerable)
        |> Stream.map(unquote({:fn, [], clauses}))
        |> CSV.encode(unquote([headers: headers] ++ csv_opts))
      end

    if into do
      quote do
        Stream.into(unquote(encoded), unquote(into))
      end
    else
      encoded
    end
  end

  # Leitet die Header aus den Schlüsseln der Map ab, die der erste Clause-Rumpf
  # zurückgibt.
  defp extract_headers(clauses) do
    Enum.find_value(clauses, fn {:->, _, [_args, body]} -> map_keys(body) end) ||
      raise ArgumentError,
            "format_csv erwartet einen Block, der jedes Element auf eine Map " <>
              "(z. B. %{\"OUTPUT\" => value}) abbildet, um daraus die Header zu bilden."
  end

  # Bei mehreren Ausdrücken zählt der letzte — das ist der Rückgabewert.
  defp map_keys({:__block__, _, exprs}), do: exprs |> List.last() |> map_keys()
  defp map_keys({:%{}, _, pairs}), do: Enum.map(pairs, fn {key, _value} -> key end)
  defp map_keys(_other), do: nil
end
