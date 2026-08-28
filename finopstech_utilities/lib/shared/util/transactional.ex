defmodule Shared.Util.Transactional do
  @moduledoc """
  Wrapt annotierte Funktionen automatisch in eine Datenbank-Transaktion.

  Statt in einer Funktion mit `c:Ecto.Repo.transact/2` zu arbeiten, annotierst
  du die Funktion mit `@transactional true`. Die unmittelbar folgende **Clause**
  so umgeschrieben das sie in einer Transaktion ausgeführt wird.

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

  ## Result Mapping

  Mit `:map_result` kann eine funktion angegeben werden, durch die das result
  der transaction gemappt werden kann. Lokale functionen werden als atom
  `:function_name` angegeben und remote functions als Tuple `{Module, :function_name}`.

      defmodule Konto do
        use Shared.Util.Transactional, repo: MyApp.Repo, map_result: :simplify_ok

        @transactional true
        def transfer(from, to, betrag) do
          Konto.belasten(from, betrag)
          Konto.gutschreiben(to, betrag)
        end

        defp simplify_ok({:ok, :ok}), do: :ok
        defp simplify_ok(result), do: result
      end

  ## Optionen

  Statt `true` kannst du `@transactional` die options für `c:Ecto.Repo.transact/2` zuweisen


      @transactional timeout: 30_000, mode: :savepoint
      def transfer(from, to, betrag) do
        # ...
      end

  wird zu:

      def transfer(from, to, betrag) do
        MyApp.Repo.transact(fn -> ... end, timeout: 30_000, mode: :savepoint)
      end

  ## Repo

  Das zu verwendende Repo gibst du einmalig bei `use` an (`repo: MyApp.Repo`).

  ## Verhalten

  - Hat eine Funktion mehrere clauses (Pattern Matching, Guards), gilt
    `@transactional` gilt nur für die **unmittelbar folgende** Function-**Clause**.
    Clauses ihne vorheriges `@transactional` Attribut bleiben unverändert:

        @transactional true
        def buchen(%Zahlung{} = z), do: Repo.insert(z)
        # ohne Transaktion — bleibt unverändert
        def buchen(nil), do: {:error, :leer}

  - Da `c:Ecto.Repo.transact/2` verwendet wird, muss `{:ok, ergebnis}` bzw.
    `{:error, grund}` zurückgegeben werden.
  """

  @doc false
  defmacro __using__(opts) do
    repo =
      Keyword.get(opts, :repo) || raise ArgumentError, "`:repo` muss als Option übergeben werden."

    map_result = Keyword.get(opts, :map_result)

    quote do
      @transactional_config %{repo: unquote(repo), map_result: unquote(map_result)}
      Module.register_attribute(__MODULE__, :transactional_clauses, accumulate: true)
      @on_definition Shared.Util.Transactional
      @before_compile Shared.Util.Transactional
    end
  end

  @doc false
  def __on_definition__(env, _kind, name, args, _guards, _body) do
    case Module.delete_attribute(env.module, :transactional) do
      value when value in [nil, false] -> :ok
      true -> register_transactional_clause(env, name, args)
      opts -> register_transactional_clause(env, name, args, opts)
    end
  end

  @doc false
  defmacro __before_compile__(%{module: module} = _env) do
    transactional_clauses = Module.get_attribute(module, :transactional_clauses)

    %{} = config = Module.get_attribute(module, :transactional_config)

    opts_by_function =
      Enum.reduce(transactional_clauses, %{}, fn {function, clause_line, opts}, acc ->
        Map.update(acc, function, %{clause_line => opts}, &Map.put(&1, clause_line, opts))
      end)

    defs =
      for {function, clause_opts} <- opts_by_function,
          {:v1, kind, _meta, clauses} = pop_definition(module, function),
          {meta, args, guards, body} <- clauses do
        {name, _arity} = function
        head = build_head(name, args, guards)

        body =
          case get_opts(clause_opts, meta) do
            nil -> body
            opts -> wrap_body(body, config, opts)
          end

        build_clause(kind, head, body)
      end

    {:__block__, [], defs}
  end

  defp register_transactional_clause(env, name, args, opts \\ []) do
    if !Keyword.keyword?(opts) do
      raise ArgumentError,
            "Shared.Util.Transactional: @transactional erwartet `true` oder eine Keyword-Liste."
    end

    Module.put_attribute(
      env.module,
      :transactional_clauses,
      {{name, length(args)}, env.line, opts}
    )
  end

  defp get_opts(clause_opts, clause_meta) do
    Map.get(clause_opts, Keyword.fetch!(clause_meta, :line))
  end

  def pop_definition(module, function) do
    definition = Module.get_definition(module, function)
    if definition, do: true = Module.delete_definition(module, function)
    definition
  end

  defp build_clause(kind, head, body) do
    quote do
      Kernel.unquote(kind)(unquote(head)) do
        unquote(body)
      end
    end
  end

  defp wrap_body(body, config, opts) when is_map_key(config, :map_result) do
    case Map.pop!(config, :map_result) do
      {nil, config} -> wrap_body(body, config, opts)
      {{mod, fun}, config} -> build_call(mod, fun, [wrap_body(body, config, opts)])
      {local_fun, config} -> build_call(local_fun, [wrap_body(body, config, opts)])
    end
  end

  defp wrap_body(body, %{repo: repo}, []) do
    quote do
      unquote(repo).transact(fn -> unquote(body) end)
    end
  end

  defp wrap_body(body, %{repo: repo}, opts) do
    quote do
      unquote(repo).transact(
        fn -> unquote(body) end,
        unquote(Macro.escape(opts))
      )
    end
  end

  defp build_head(name, args, guards) do
    # mehrere `when`-Guards wieder als `head when g1 when g2` zusammensetzen
    Enum.reduce(guards, {name, [], args}, fn
      guard, head -> {:when, [], [head, guard]}
    end)
  end

  def build_call(fun, args) when is_atom(fun) do
    quote do
      unquote(fun)(unquote_splicing(args))
    end
  end

  def build_call(mod, fun, args) when is_atom(fun) do
    quote do
      unquote(mod).unquote(fun)(unquote_splicing(args))
    end
  end
end
