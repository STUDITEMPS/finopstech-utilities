defmodule Shared.Enum do
  @moduledoc """
  Base module to work with enumerated types.

  ## Usage

      defmodule MyEnum do
        use Shared.Enum,
          values: [Foo, Bar, BooYah],
          urn_prefix: "tech.studitemps:context:entity:"
      end

  This Module will now provide one guard:

      iex> MyEnum.is_value(MyEnum.Foo)
      true
      iex> MyEnum.is_value(MyEnum.Baz)
      false

  and 4 functions:

      iex> MyEnum.values()
      [MyEnum.Foo, MyEnum.Bar, MyEnum.BooYah]

      iex> MyEnum.to_urn(MyEnum.BooYah)
      "tech.studitemps:context:entity:boo_yah"

      iex> MyEnum.from_urn("tech.studitemps:context:entity:bar")
      MyEnum.Bar

  """

  @doc false
  def to_string(value, enum) do
    case return_suffix(Module.split(value), Module.split(enum)) do
      error when error in [:no_suffix, :not_a_prefix] ->
        raise ArgumentError, "#{inspect(value)} is not a submodule of #{inspect(enum)}"

      {:ok, suffix} ->
        Enum.map_join(suffix, ".", &Macro.underscore/1)
    end
  end

  def to_urn(value) do
    enum = value.enum()

    if function_exported?(enum, :to_urn, 1) do
      enum.to_urn(value)
    else
      raise ArgumentError, "Enum #{inspect(enum)} does not specify a URN prefix"
    end
  end

  @empty_block (quote do
                end)

  @doc false
  defmacro __using__(opts) do
    values = Keyword.fetch!(opts, :values)

    quote do
      unquote_splicing(build_modules(values, __CALLER__))
      unquote(optionaly_build_urn_functions(opts))

      @type t :: unquote(build_type_spec(values))

      @values unquote(values)

      defguard is_value(term) when term in @values

      @spec values :: [t()]
      def values, do: @values
    end
  end

  @doc false
  defmacro _generate_to_urn(env) do
    if Module.defines?(env.module, {:to_urn, 1}) do
      @empty_block
    else
      quote do
        @spec to_urn(t()) :: String.t()
        def to_urn(value) when is_value(value),
          do: @urn_prefix <> unquote(__MODULE__).to_string(value, __MODULE__)
      end
    end
  end

  @doc false
  defmacro _generate_from_urn(env) do
    if Module.defines?(env.module, {:from_urn, 1}) do
      @empty_block
    else
      quote do
        @urns Map.new(
                @values,
                &{@urn_prefix <> unquote(__MODULE__).to_string(&1, __MODULE__), &1}
              )
        @spec from_urn(String.t()) :: t()
        def from_urn(urn) when is_map_key(@urns, urn), do: Map.get(@urns, urn)
      end
    end
  end

  defp build_modules(values, env) do
    Enum.map(values, fn {:__aliases__, _ctx, [name]} ->
      module = Module.concat(env.module, name)

      Module.create(
        module,
        quote do
          @enum unquote(env.module)
          def enum, do: @enum
        end,
        env
      )

      quote do
        alias unquote(module)
      end
    end)
  end

  defp optionaly_build_urn_functions(opts) do
    case Keyword.fetch(opts, :urn_prefix) do
      {:ok, urn_prefix} when is_binary(urn_prefix) ->
        urn_prefix =
          if String.ends_with?(urn_prefix, ":"), do: urn_prefix, else: urn_prefix <> ":"

        quote do
          @urn_prefix unquote(urn_prefix)
          @before_compile {unquote(__MODULE__), :_generate_to_urn}
          @before_compile {unquote(__MODULE__), :_generate_from_urn}
        end

      :error ->
        @empty_block
    end
  end

  defp build_type_spec([] = values), do: values
  defp build_type_spec([_] = values), do: values
  defp build_type_spec([_, _] = values), do: {:|, [], values}
  defp build_type_spec([a | values]), do: {:|, [], [a, build_type_spec(values)]}

  defp return_suffix([], _), do: :no_suffix
  defp return_suffix(suffix, []) when is_list(suffix), do: {:ok, suffix}
  defp return_suffix([h | list], [h | prefix]), do: return_suffix(list, prefix)
  defp return_suffix(list, _prefix) when is_list(list), do: :not_a_prefix
end
