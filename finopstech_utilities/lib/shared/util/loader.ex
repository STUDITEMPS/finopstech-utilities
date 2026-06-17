defmodule Shared.Util.Loader do
  @moduledoc """
  Lädt automatisch Entities anhand ihrer ID, bevor eine Funktion ausgeführt wird.

  Statt in jeder Funktion zuerst `Repo.get!/2` aufzurufen, annotierst du die
  Funktion mit `@load` und gibst pro Parameter das Schema an. Beim Aufruf
  übergibst du die ID, im Funktionsrumpf kommt bereits die geladene Entity an.

  ## Verwendung

      defmodule Accounts do
        use Shared.Util.Loader, repo: MyApp.Repo

        @load user: User
        def name_of(user) do
          # `user` ist hier bereits %User{}, nicht mehr die ID
          user.name
        end
      end

      Accounts.name_of(123)   # => Repo.get!(User, 123) -> Body läuft mit %User{}
      Accounts.name_of(999)   # ** (Ecto.NoResultsError)

  Mehrere Parameter — nur die annotierten werden geladen, der Rest läuft
  unverändert durch:

      @load from: Account, to: Account
      def transfer(from, to, amount) do
        # from und to sind %Account{}, amount bleibt der rohe Wert
        Account.move(from, to, amount)
      end

      Accounts.transfer(1, 2, 100)

  Der Parameter darf auch per Keyword-Pattern im Funktionskopf gebunden werden —
  `@load` greift dann den Key heraus:

      @load user: User
      def login(user: user) do
        # user ist %User{}
        user.name
      end

      Accounts.login(user: 123)

  ## Repo

  Das Standard-Repo gibst du einmalig bei `use` an (`repo: MyApp.Repo`). Im
  `@load` steht dann nur `parametername: Schema`. Pro Annotation kannst du das
  Repo bei Bedarf überschreiben, indem du statt des Schemas ein
  `{Repo, Schema}`-Tupel angibst:

      @load user: {MyApp.OtherRepo, User}

  ## Verhalten bei nicht gefundener Entity

  Es wird `Repo.get!/2` verwendet — fehlt die Entity, fliegt eine
  `Ecto.NoResultsError`. (Es genügt jedes Modul, das `get!/2` bereitstellt.)

  ## Einschränkungen

  - Der annotierte Parameter muss eine einfache Variable mit dem im `@load`
    genannten Namen sein — oder per Keyword-Pattern unter diesem Key gebunden
    werden (`def f(user: user)`).
  - Guards laufen auf der **rohen ID** (vor dem Laden), nicht auf der Entity.
  - Default-Argumente (`\\\\`) auf geladenen Parametern werden nicht unterstützt.
  - `@load` gilt nur für die unmittelbar folgende Funktionsdefinition.
  """

  @doc false
  defmacro __using__(opts) do
    repo = Keyword.get(opts, :repo)

    quote do
      @loader_default_repo unquote(repo)
      Module.register_attribute(__MODULE__, :loaded_functions, accumulate: true)
      @on_definition Shared.Util.Loader
      @before_compile Shared.Util.Loader
    end
  end

  @doc false
  def __on_definition__(env, _kind, name, args, _guards, _body) do
    # `@on_definition` kann den Body nicht ändern. Wir merken uns hier nur,
    # welche Funktion ein `@load` trägt; umgeschrieben wird in `__before_compile__`.
    # zurücksetzen, damit `@load` wirklich nur für diese eine Funktion gilt
    case Module.delete_attribute(env.module, :load) do
      nil ->
        :ok

      spec ->
        Module.put_attribute(env.module, :loaded_functions, {name, length(args), spec})
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    module = env.module
    default_repo = Module.get_attribute(module, :loader_default_repo)

    defs =
      module
      |> Module.get_attribute(:loaded_functions)
      |> Enum.map(&wrap_function(module, &1, default_repo))

    {:__block__, [], defs}
  end

  defp wrap_function(module, {name, arity, spec}, default_repo) do
    {:v1, kind, _meta, clauses} = Module.get_definition(module, {name, arity})
    Module.delete_definition(module, {name, arity})

    rebuilt = Enum.map(clauses, &rebuild_clause(&1, kind, name, spec, default_repo))
    {:__block__, [], rebuilt}
  end

  defp rebuild_clause({_meta, args, guards, body}, kind, name, spec, default_repo) do
    loads =
      Enum.map(spec, fn {param, source} ->
        {repo, schema} = resolve_source(source, default_repo, name)
        arg = find_var(args, param) || raise_missing(param, name)

        quote do
          unquote(arg) = unquote(repo).get!(unquote(schema), unquote(arg))
        end
      end)

    head = build_head(name, args, guards)

    new_body =
      quote do
        unquote_splicing(loads)
        unquote(body)
      end

    quote do
      Kernel.unquote(kind)(unquote(head)) do
        unquote(new_body)
      end
    end
  end

  defp build_head(name, args, []), do: {name, [], args}

  defp build_head(name, args, guards) do
    # mehrere `when`-Guards wieder als `head when g1 when g2` zusammensetzen
    Enum.reduce(guards, {name, [], args}, fn guard, acc -> {:when, [], [acc, guard]} end)
  end

  # Findet die Variable, die der annotierte Parameter bindet — entweder als
  # einfacher Parameter (`def f(user)`) oder als Key in einem Keyword-Pattern
  # im Funktionskopf (`def f(user: user)` bzw. `def f(user: u)`).
  defp find_var(args, param), do: Enum.find_value(args, &find_var_in(&1, param))

  # einfacher Variablen-Parameter: def f(user)
  defp find_var_in({name, _meta, context} = var, param) when is_atom(context) do
    if name == param, do: var
  end

  # Keyword-Pattern: def f(user: user) / def f(user: u, role: role)
  defp find_var_in(pattern, param) when is_list(pattern) do
    Enum.find_value(pattern, fn
      {^param, {_name, _meta, context} = var} when is_atom(context) -> var
      _ -> nil
    end)
  end

  defp find_var_in(_other, _param), do: nil

  defp resolve_source({repo, schema}, _default, _name) when is_atom(repo) and is_atom(schema), do: {repo, schema}

  defp resolve_source(schema, nil, name) when is_atom(schema) do
    raise ArgumentError,
          "Shared.Util.Loader: für @load auf #{name} wurde nur das Schema " <>
            "#{inspect(schema)} angegeben, aber kein Standard-Repo bei `use` gesetzt. " <>
            "Nutze `use Shared.Util.Loader, repo: MeinRepo` oder ein {Repo, Schema}-Tupel."
  end

  defp resolve_source(schema, default_repo, _name) when is_atom(schema), do: {default_repo, schema}

  defp raise_missing(param, name) do
    raise ArgumentError,
          "Shared.Util.Loader: @load nennt Parameter #{inspect(param)}, aber #{name} hat " <>
            "keinen einfachen Variablen-Parameter mit diesem Namen."
  end
end
