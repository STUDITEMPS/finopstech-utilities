if Code.ensure_loaded?(Ecto.ParameterizedType) do
  defmodule Shared.EnumType do
    @moduledoc """
    Ecto.Type to store enumerated types created with `Shared.Enum`.

    ## Usage

        schema "entities" do
          field(:my_enum, Shared.EnumType, enum: MyEnum, persist_urn: true)
        end

    """

    use Ecto.ParameterizedType

    def type(_params), do: :string

    def init(opts) do
      validate_opts(opts)

      opts
      |> Map.new()
      |> prepare_mapping()
    end

    def cast(nil, _), do: {:ok, nil}
    def cast(data, %{mapping: mapping}) when is_map_key(mapping, data), do: {:ok, data}

    def cast(data, %{inverse_mapping: mapping}) when is_map_key(mapping, data),
      do: Map.fetch(mapping, data)

    def cast(_data, _params), do: :error

    def load(nil, _loader, _params), do: {:ok, nil}
    def load(data, _loader, %{inverse_mapping: mapping}), do: Map.fetch(mapping, data)

    def dump(nil, _dumper, _params), do: {:ok, nil}
    def dump(data, _dumper, %{mapping: mapping}), do: Map.fetch(mapping, data)

    def equal?(a, a, _params), do: true

    def equal?(a, b, %{mapping: mapping}) when is_map_key(mapping, a),
      do: b == Map.get(mapping, a)

    def equal?(a, b, %{inverse_mapping: mapping}) when is_map_key(mapping, a),
      do: b == Map.get(mapping, a)

    def equal?(_a, _b, _params), do: false

    defp validate_opts(opts) do
      case Keyword.fetch(opts, :enum) do
        :error -> raise ArgumentError, "Missing enum module"
        {:ok, module} when not is_atom(module) -> raise ArgumentError, "enum: is not a module"
        {:ok, _module} -> :ok
      end
    end

    defp prepare_mapping(%{enum: enum} = params) do
      mapping =
        if params[:persist_urn],
          do: Map.new(enum.values(), &{&1, enum.to_urn(&1)}),
          else: Map.new(enum.values(), &{&1, Shared.Enum.to_string(&1, enum)})

      params
      |> Map.put(:mapping, mapping)
      |> Map.put(:inverse_mapping, Map.new(mapping, fn {k, v} -> {v, k} end))
    end
  end
end
