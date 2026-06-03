defmodule FinopstechUtilities.ReleaseTask do
  @moduledoc """
  Ermöglicht es, Release-Tasks dynamisch aus der Shell aufzurufen.

  ## Einen Release-Task definieren

      defmodule MeineApp.ReleaseTasks.Migrieren do
        @behaviour FinopstechUtilities.ReleaseTask

        @impl true
        def ausfuehren(_args) do
          # ...
        end
      end

  ## Einen Release-Task aufrufen

  Um den oben definierten task auszuführen kann man den release task wie folgt aufrufen.

      bin/meine_app eval 'FinopstechUtilities.ReleaseTask.ausfuehren(app: :meine_app)' migrieren --schritte 3

  Oder auf Heroku:

      heroku run --app meine-app "_build/prod/rel/meine_app/bin/meine_app eval 'FinopstechUtilities.ReleaseTask.ausfuehren(app: :meine_app)' migrieren --schritte 3"

  `ausfuehren/1` nimmt sich das erste Argument (`"migrieren"`), sucht dazu den
  passenden Release-Task und übergibt ihm die restlichen Argumente
  (`["--schritte", "3"]`).
  """

  alias FinopstechUtilities.Modules

  @type args :: [String.t()]

  @type opts :: [
          {:app, atom()}
          | {:group, Modules.group_identifier()}
          | {:in_namespace, module()}
        ]

  @doc """
  Führt den Release-Task aus.

  Bekommt die Liste der Shell-Argumente, die hinter dem Task-Namen übergeben
  wurden.
  """
  @callback ausfuehren(args()) :: :ok | {:ok, term} | {:error, term}

  @doc "Wie `ausfuehren(System.argv(), [])`"
  @spec ausfuehren() :: :ok | no_return()
  def ausfuehren, do: ausfuehren(System.argv(), [])

  def ausfuehren([task | _] = args) when is_binary(task), do: ausfuehren(args, [])

  @doc """
  Wie `ausfuehren/2`, aber verwendet die command line argumente als `args`.

  Siehe: `System.argv/0`.
  """
  @spec ausfuehren(opts()) :: :ok | no_return()
  def ausfuehren(opts), do: ausfuehren(System.argv(), opts)

  @doc """
  Sucht den zum ersten Argument passenden Release-Task und führt ihn mit den restlichen Argumenten aus.

  Ohne die explizite`args` werden die Argumente aus `System.argv/0` gelesen.

  Der ReleaseTask wird anhand des ersten arguments ermittelt. Dieser muss der underscore name des moduls sein.
  Wenn ReleaseTasks in einem namespace gesucht werden (default) reicht es den namen ohne namespace anzugeben.

  #### Beispiel



  Der Rückgabewert des ausgeführten Tasks wird ausgewertet: `:ok` sowie ein
  `{:ok, _}`-Tupel gelten als Erfolg, ein `{:error, _}`-Tupel löst eine Exception
  aus.

  ## Optionen

    * `:in_namespace` - Konfiguriert den Namespace in dem ReleaseTasks gesucht werden.
                        Default: AppModule.ReleaseTasks -> Bsp: Freigabe.ReleaseTasks
    * `:group` - Verwendet Module der angegebenen Gruppe asl ReleaseTasks
               (siehe `FinopstechUtilities.Modules`).
    * `:app` - die Applikation (als Atom), in deren Modulen nach Release-Tasks
               gesucht wird.
  """
  @spec ausfuehren(args(), opts()) :: :ok | no_return()
  def ausfuehren(argv, opts) when is_list(argv) and is_list(opts) do
    opts = validate_opts!(opts)
    tasks = lade_tasks(opts)

    {module, function, arguments} = ermittle_task(tasks, argv, opts)

    case apply(module, function, arguments) do
      {:ok, _} ->
        :ok

      :ok ->
        :ok

      {:error, error} ->
        raise "#{inspect(module)} ist fehlgeschlagen: #{inspect(error)}"
    end
  end

  defp validate_opts!(opts) do
    opts =
      Keyword.put_new_lazy(opts, :app, fn ->
        try do
          Modules.current_app!()
        rescue
          RuntimeError ->
            raise "Unable to fetch application for current Process. Please provide the app: option."
        end
      end)

    if Keyword.has_key?(opts, :group) do
      opts
    else
      Keyword.put_new_lazy(opts, :in_namespace, fn ->
        Module.concat(Macro.camelize("#{opts[:app]}"), ReleaseTasks)
      end)
    end
  end

  defp lade_module(opts) do
    criteria = Keyword.take(opts, [:in_namespace, :group])

    case opts[:app] do
      nil -> Modules.find(criteria)
      app -> Modules.find(Modules.from_app!(app), criteria)
    end
  end

  defp lade_tasks(opts) do
    namespace = opts[:in_namespace]

    for module <- lade_module(opts),
        module != __MODULE__,
        into: %{},
        do: {task_name(module, namespace), module}
  end

  @doc false
  @spec ermittle_task(%{String.t() => module()}, args(), opts()) ::
          {module(), atom(), [args()]} | no_return()
  def ermittle_task(tasks, argv, opts \\ [])
  def ermittle_task(tasks, [], _opts), do: kein_task_angegeben(tasks)
  def ermittle_task(tasks, _argv, opts) when map_size(tasks) < 1, do: keine_tasks(opts)

  def ermittle_task(tasks, [task | args], _opts) when is_map_key(tasks, task) do
    module = tasks[task]

    # Das modul sollte existieren, da es über die app spec ermittelt wurde.
    Code.ensure_loaded!(module)

    if not function_exported?(module, :ausfuehren, 1) do
      raise "ReleaseTask #{inspect(module)} implementiert nicht das #{inspect(__MODULE__)} behaviour"
    end

    {module, :ausfuehren, [args]}
  end

  def ermittle_task(tasks, [task | _args], _opts), do: task_nicht_gefunden(task, tasks)

  defp task_name(module, nil), do: Macro.underscore(module)

  defp task_name(module, namespace) do
    prefix = Macro.underscore(namespace) <> "/"

    case Macro.underscore(module) do
      ^prefix <> task_name -> task_name
      _ -> raise "Module #{inspect(module)} is not in expected namespace #{inspect(namespace)}"
    end
  end

  defp keine_tasks(opts), do: raise(keine_tasks_meldung(opts))

  defp keine_tasks_meldung(opts) do
    cond do
      namespace = opts[:in_namespace] ->
        """
        Es wurden keine Release-Tasks im Namespace #{inspect(namespace)} gefunden.
        Erstellen Sie ein Modul unterhalb dieses Namespace, das das #{inspect(__MODULE__)} Verhalten implementiert.
        """

      group = opts[:group] ->
        """
        Es wurden keine Release-Tasks mit der Gruppenmarkierung #{inspect(group)} gefunden.
        Markieren Sie ein Modul mit `use FinopstechUtilities.Modules, group: #{inspect(group)}`, das das #{inspect(__MODULE__)} Verhalten implementiert.
        """

      true ->
        "Die Applikation definiert keine Release-Tasks."
    end
  end

  defp kein_task_angegeben(tasks) do
    raise """
    Es wurde kein Task angegeben.
    #{verfuegbare_tasks_liste(tasks)}
    """
  end

  defp task_nicht_gefunden(task, tasks) do
    case find_similar(task, tasks) do
      nil ->
        raise """
        Task #{inspect(task)} ist nicht vorhanden. Verfügbare Tasks sind:
        #{verfuegbare_tasks_liste(tasks)}
        """

      vorschlag ->
        raise """
        Task #{inspect(task)} ist nicht vorhanden. Verfügbare Tasks sind:
          Meintest du #{inspect(vorschlag)}?
        """
    end
  end

  defp find_similar(task, tasks) do
    tasks
    |> Map.keys()
    |> Enum.map(&{String.jaro_distance(&1, task), &1})
    |> Enum.sort()
    |> Enum.find_value(fn
      {distance, task_name} when distance > 0.5 -> task_name
      _ -> nil
    end)
  end

  defp verfuegbare_tasks_liste(tasks), do: Enum.map_join(Enum.sort(Map.keys(tasks)), "\n", &"  - #{&1}")
end
