defmodule Shared.Util.Transactional do
  @moduledoc """
  Wickelt annotierte Funktionen automatisch in eine Datenbank-Transaktion.

  Statt den Rumpf einer Funktion von Hand in `Repo.transact/1` zu legen,
  annotierst du die Funktion mit `@transactional true`. Die unmittelbar folgende
  Funktionsdefinition wird dann so umgeschrieben, dass ihr ursprünglicher Rumpf
  innerhalb von `Repo.transact/1` (mit einer arity-0-Funktion) läuft.

  ## Verwendung

      defmodule Konto do
        use Shared.Util.Transactional, repo: MyApp.Repo

        @transactional true
        def transfer(from, to, betrag) do
          Konto.belasten(from, betrag)
          Konto.gutschreiben(to, betrag)
        end
      end

  Der obige Code ist äquivalent zu:

      def transfer(from, to, betrag) do
        MyApp.Repo.transact(fn ->
          Konto.belasten(from, betrag)
          Konto.gutschreiben(to, betrag)
        end)
      end

  ## Repo

  Das zu verwendende Repo gibst du einmalig bei `use` an (`repo: MyApp.Repo`).
  Es genügt jedes Modul, das `transact/1` bereitstellt.

  ## Verhalten

  - `@transactional true` gilt nur für die **unmittelbar folgende** Funktions-
    **Klausel**.
  - Hat eine Funktion mehrere Klauseln (Pattern Matching, Guards), wird nur der
    Rumpf der **annotierten** Klauseln in die Transaktion gewickelt. Nicht
    annotierte Klauseln bleiben exakt so, wie sie geschrieben wurden:

        @transactional true
        def buchen(%Zahlung{} = z), do: Repo.insert(z)
        # ohne Transaktion — bleibt unverändert
        def buchen(nil), do: {:error, :leer}

  - Guards und der Funktionskopf bleiben unverändert; nur der Rumpf wird gewrappt.
  - Da `Repo.transact/1` verwendet wird, sollte der Rumpf typischerweise
    `{:ok, ergebnis}` bzw. `{:error, grund}` zurückgeben — der Rückgabewert wird
    von `transact/1` entsprechend behandelt.
  """

  @doc false
  defmacro __using__(opts) do
    repo = Keyword.get(opts, :repo)

    quote do
      @transaction_repo unquote(repo)
      Module.register_attribute(__MODULE__, :transactional_clauses, accumulate: true)
      @on_definition Shared.Util.Transactional
      @before_compile Shared.Util.Transactional
    end
  end

  @doc false
  def __on_definition__(env, _kind, name, args, _guards, _body) do
    # `@on_definition` kann den Body nicht ändern. Wir merken uns hier nur, welche
    # einzelne Klausel ein `@transactional true` trägt — identifiziert über ihre
    # Zeile (`env.line`). In `__before_compile__` wird genau diese Klausel anhand
    # ihrer Zeile in der Definition wiedergefunden und umgeschrieben. Zurücksetzen,
    # damit die Annotation wirklich nur für diese eine Klausel gilt.
    if Module.delete_attribute(env.module, :transactional) do
      Module.put_attribute(env.module, :transactional_clauses, {name, length(args), env.line})
    else
      :ok
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    module = env.module

    clauses = Module.get_attribute(module, :transactional_clauses)

    # pro Funktion ({name, arity}) die Menge der annotierten Zeilen sammeln
    lines_by_function =
      Enum.reduce(clauses, %{}, fn {name, arity, line}, acc ->
        Map.update(acc, {name, arity}, MapSet.new([line]), &MapSet.put(&1, line))
      end)

    repo =
      case map_size(lines_by_function) do
        0 -> nil
        _ -> Module.get_attribute(module, :transaction_repo) || raise_missing_repo(module)
      end

    defs =
      Enum.map(lines_by_function, fn {fun, lines} -> wrap_function(module, fun, lines, repo) end)

    {:__block__, [], defs}
  end

  defp wrap_function(module, {name, arity}, annotated_lines, repo) do
    {:v1, kind, _meta, clauses} = Module.get_definition(module, {name, arity})
    true = Module.delete_definition(module, {name, arity})

    rebuilt = Enum.map(clauses, &rebuild_clause(&1, kind, name, annotated_lines, repo))
    {:__block__, [], rebuilt}
  end

  defp rebuild_clause({meta, args, guards, body}, kind, name, annotated_lines, repo) do
    head = build_head(name, args, guards)
    new_body = maybe_wrap(body, MapSet.member?(annotated_lines, meta[:line]), repo)

    quote do
      Kernel.unquote(kind)(unquote(head)) do
        unquote(new_body)
      end
    end
  end

  # Nur annotierte Klauseln werden gewrappt; alle anderen bleiben unverändert.
  defp maybe_wrap(body, false, _repo), do: body

  defp maybe_wrap(body, true, repo) do
    quote do
      unquote(repo).transact(fn -> unquote(body) end)
    end
  end

  defp build_head(name, args, []), do: {name, [], args}

  defp build_head(name, args, guards) do
    # mehrere `when`-Guards wieder als `head when g1 when g2` zusammensetzen
    Enum.reduce(guards, {name, [], args}, fn guard, acc -> {:when, [], [acc, guard]} end)
  end

  defp raise_missing_repo(module) do
    raise ArgumentError,
          "Shared.Util.Transactional: In #{inspect(module)} wird @transactional verwendet, " <>
            "aber bei `use` wurde kein Repo gesetzt. Nutze `use Shared.Util.Transactional, repo: MeinRepo`."
  end
end
