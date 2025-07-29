defmodule FinopstechUtilities.Modules do
  @moduledoc """
  ## Usage

      defmodule My.EventListener do
        use FinopstechUtilities.Modules, group: :event_listeners
      end

      defmodule My.Application do
        alias FinopstechUtilities.Modules

        def start(_type, _args) do
          children = Modules.find(group: :event_listeners)

          opts = [strategy: :one_for_one, name: My.Supervisor]
          Supervisor.start_link(children, opts)
        end
      end

  ## Environment Specific Groups

  Finding Modules just in specific Environments can be achieved by defining
  multiple groups, one for each relevant environment:

      defmodule My.EventListener do
        use FinopstechUtilities.Modules,
          group: {:event_listeners, env: :dev},
          group: {:event_listeners, env: :test}
      end


      defmodule My.Application do
        alias FinopstechUtilities.Modules

        def start(_type, _args) do
          # Will contain `My.EventListener` only for :dev and :test builds
          children = Modules.find(group: {:event_listeners, env: Mix.env()})

          opts = [strategy: :one_for_one, name: My.Supervisor]
          Supervisor.start_link(children, opts)
        end
      end
  """

  @type group_identifier :: term()

  defmacro __using__(opts) do
    validate_opts!(opts)

    Module.register_attribute(__CALLER__.module, :module_markers, persist: true, accumulate: true)

    quote do
      @module_markers unquote(opts)
    end
  end

  @doc """
  Find modules that match the given criteria.

  This function will search through the modules of the current application, when
  not given en explicit list of modules.

  ## Examples

      iex> find(group: :event_listeners)
      [My.EventListener]

      iex> find(group: {:event_listeners, env: :test})
      [Test.EventListener]

  """
  @spec find(atom(), group: term()) :: [module()]
  def find(modules \\ from_app!(), criteria) do
    Enum.filter(modules, &matches?(&1, criteria))
  end

  @spec matches?(module(), group: term()) :: boolean()
  def matches?(module, criteria) when is_list(criteria) do
    markers = get_markers(module)

    Enum.all?(criteria, fn
      {key, _} = marker when is_atom(key) -> marker in markers
      _ -> raise ArgumentError, "criteria must be a keyword list, got: #{inspect(criteria)}"
    end)
  end

  @doc """
  Returns a list of modules in the given application.

  Raises if the application is not loaded.
  """
  @spec from_app!(atom()) :: [module()]
  def from_app!(app \\ current_app!()) when is_atom(app) do
    case Application.spec(app, :modules) do
      nil -> raise "Application #{app} is not loaded"
      modules -> modules
    end
  end

  @doc """
  Returns the name of the application of the current process.

  Raises if the current process does not belong to an application.
  """
  @spec current_app!() :: atom()
  def current_app! do
    case :application.get_application() do
      {:ok, app} -> app
      :undefined -> raise "Current process (#{inspect(self())}) does not belong to an application"
    end
  end

  @doc """
  Reads the module configured markers from a module.
  """
  @spec get_markers(module()) :: keyword()
  def get_markers(module) do
    module.__info__(:attributes)
    |> Keyword.get_values(:module_markers)
    |> Enum.concat()
  end

  defp validate_opts!(opts) do
    Enum.each(opts, fn
      {:group, _value} ->
        :ok

      {invalid_key, _value} when is_atom(invalid_key) ->
        raise ArgumentError, "Invalid Key: #{inspect(invalid_key)}"

      _ ->
        raise ArgumentError, "opts must be a keyword list, got: #{inspect(opts)}"
    end)
  end
end
