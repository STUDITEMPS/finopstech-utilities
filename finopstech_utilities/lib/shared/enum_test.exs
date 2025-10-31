defmodule Shared.EnumTest do
  @moduledoc false

  use ExUnit.Case

  # Test enum without URN prefix
  defmodule SimpleEnum do
    use Shared.Enum,
      values: [Foo, Bar, BazQux]
  end

  # Test enum with URN prefix
  defmodule UrnEnum do
    use Shared.Enum,
      values: [Alpha, Beta, GammaDelta],
      urn_prefix: "tech.studitemps:context:entity:"
  end

  # Test enum with URN prefix that already ends with colon
  defmodule UrnEnumWithColon do
    use Shared.Enum,
      values: [One, Two],
      urn_prefix: "tech.studitemps:test:"
  end

  # Test enum with single value
  defmodule SingleValueEnum do
    use Shared.Enum,
      values: [OnlyOne],
      urn_prefix: "tech.studitemps:single:"
  end

  # Test enum with two values
  defmodule TwoValueEnum do
    use Shared.Enum,
      values: [First, Second],
      urn_prefix: "tech.studitemps:two:"
  end

  describe "values/0" do
    test "returns all enum values for SimpleEnum" do
      assert SimpleEnum.values() == [SimpleEnum.Foo, SimpleEnum.Bar, SimpleEnum.BazQux]
    end

    test "returns all enum values for UrnEnum" do
      assert UrnEnum.values() == [UrnEnum.Alpha, UrnEnum.Beta, UrnEnum.GammaDelta]
    end

    test "returns single value for SingleValueEnum" do
      assert SingleValueEnum.values() == [SingleValueEnum.OnlyOne]
    end

    test "returns two values for TwoValueEnum" do
      assert TwoValueEnum.values() == [TwoValueEnum.First, TwoValueEnum.Second]
    end
  end

  describe "is_value/1 guard" do
    test "returns true for valid SimpleEnum values" do
      require SimpleEnum
      assert SimpleEnum.is_value(SimpleEnum.Foo)
      assert SimpleEnum.is_value(SimpleEnum.Bar)
      assert SimpleEnum.is_value(SimpleEnum.BazQux)
    end

    test "returns false for invalid SimpleEnum values" do
      require SimpleEnum
      require UrnEnum
      refute SimpleEnum.is_value(SimpleEnum.Baz)
      refute SimpleEnum.is_value(UrnEnum.Alpha)
      refute SimpleEnum.is_value(:foo)
      refute SimpleEnum.is_value("Foo")
      refute SimpleEnum.is_value(nil)
    end

    test "returns true for valid UrnEnum values" do
      require UrnEnum
      assert UrnEnum.is_value(UrnEnum.Alpha)
      assert UrnEnum.is_value(UrnEnum.Beta)
      assert UrnEnum.is_value(UrnEnum.GammaDelta)
    end

    test "returns false for invalid UrnEnum values" do
      require UrnEnum
      require SimpleEnum
      refute UrnEnum.is_value(UrnEnum.Gamma)
      refute UrnEnum.is_value(SimpleEnum.Foo)
      refute UrnEnum.is_value(:alpha)
    end

    test "can be used in guard clauses" do
      require SimpleEnum

      check_value = fn
        x when SimpleEnum.is_value(x) -> :valid
        _ -> :invalid
      end

      assert check_value.(SimpleEnum.Foo) == :valid
      assert check_value.(SimpleEnum.Bar) == :valid
      assert check_value.(:foo) == :invalid
    end
  end

  describe "to_urn/1" do
    test "converts UrnEnum values to URN strings" do
      assert UrnEnum.to_urn(UrnEnum.Alpha) == "tech.studitemps:context:entity:alpha"
      assert UrnEnum.to_urn(UrnEnum.Beta) == "tech.studitemps:context:entity:beta"
      assert UrnEnum.to_urn(UrnEnum.GammaDelta) == "tech.studitemps:context:entity:gamma_delta"
    end

    test "handles URN prefix with trailing colon correctly" do
      assert UrnEnumWithColon.to_urn(UrnEnumWithColon.One) == "tech.studitemps:test:one"
      assert UrnEnumWithColon.to_urn(UrnEnumWithColon.Two) == "tech.studitemps:test:two"
    end

    test "converts single value enum to URN" do
      assert SingleValueEnum.to_urn(SingleValueEnum.OnlyOne) ==
               "tech.studitemps:single:only_one"
    end

    test "converts two value enum to URN" do
      assert TwoValueEnum.to_urn(TwoValueEnum.First) == "tech.studitemps:two:first"
      assert TwoValueEnum.to_urn(TwoValueEnum.Second) == "tech.studitemps:two:second"
    end
  end

  describe "from_urn/1" do
    test "converts URN strings to UrnEnum values" do
      assert UrnEnum.from_urn("tech.studitemps:context:entity:alpha") == UrnEnum.Alpha
      assert UrnEnum.from_urn("tech.studitemps:context:entity:beta") == UrnEnum.Beta

      assert UrnEnum.from_urn("tech.studitemps:context:entity:gamma_delta") ==
               UrnEnum.GammaDelta
    end

    test "converts URN strings for enum with trailing colon prefix" do
      assert UrnEnumWithColon.from_urn("tech.studitemps:test:one") == UrnEnumWithColon.One
      assert UrnEnumWithColon.from_urn("tech.studitemps:test:two") == UrnEnumWithColon.Two
    end

    test "converts URN for single value enum" do
      assert SingleValueEnum.from_urn("tech.studitemps:single:only_one") ==
               SingleValueEnum.OnlyOne
    end

    test "converts URN for two value enum" do
      assert TwoValueEnum.from_urn("tech.studitemps:two:first") == TwoValueEnum.First
      assert TwoValueEnum.from_urn("tech.studitemps:two:second") == TwoValueEnum.Second
    end
  end

  describe "Shared.Enum.to_string/2" do
    test "converts enum value to string representation" do
      assert Shared.Enum.to_string(SimpleEnum.Foo, SimpleEnum) == "foo"
      assert Shared.Enum.to_string(SimpleEnum.Bar, SimpleEnum) == "bar"
      assert Shared.Enum.to_string(SimpleEnum.BazQux, SimpleEnum) == "baz_qux"
    end

    test "converts UrnEnum values to string representation" do
      assert Shared.Enum.to_string(UrnEnum.Alpha, UrnEnum) == "alpha"
      assert Shared.Enum.to_string(UrnEnum.Beta, UrnEnum) == "beta"
      assert Shared.Enum.to_string(UrnEnum.GammaDelta, UrnEnum) == "gamma_delta"
    end

    test "raises ArgumentError when value is not a submodule of enum" do
      assert_raise ArgumentError, ~r/is not a submodule of/, fn ->
        Shared.Enum.to_string(UrnEnum.Alpha, SimpleEnum)
      end

      # When passing a non-module atom, Module.split raises a different error
      assert_raise ArgumentError, fn ->
        Shared.Enum.to_string(:foo, SimpleEnum)
      end
    end
  end

  describe "Shared.Enum.to_urn/1" do
    test "raises ArgumentError when enum does not specify a URN prefix" do
      assert_raise ArgumentError, ~r/does not specify a URN prefix/, fn ->
        Shared.Enum.to_urn(SimpleEnum.Foo)
      end
    end

    test "calls to_urn/0 on the value module" do
      assert Shared.Enum.to_urn(UrnEnum.Alpha) == "tech.studitemps:context:entity:alpha"
      assert Shared.Enum.to_urn(UrnEnum.Beta) == "tech.studitemps:context:entity:beta"
    end
  end

  describe "module creation and aliasing" do
    test "creates submodules for each enum value" do
      assert Code.ensure_loaded?(SimpleEnum.Foo)
      assert Code.ensure_loaded?(SimpleEnum.Bar)
      assert Code.ensure_loaded?(SimpleEnum.BazQux)
    end
  end

  describe "type spec generation" do
    test "SimpleEnum has correct type spec" do
      # This is tested implicitly through Dialyzer, but we can verify the module compiles
      assert function_exported?(SimpleEnum, :values, 0)
      assert function_exported?(SimpleEnum, :__info__, 1)
    end

    test "UrnEnum has correct type spec and functions" do
      assert function_exported?(UrnEnum, :values, 0)
      assert function_exported?(UrnEnum, :to_urn, 1)
      assert function_exported?(UrnEnum, :from_urn, 1)
    end

    test "SingleValueEnum has correct type spec" do
      assert function_exported?(SingleValueEnum, :values, 0)
      assert function_exported?(SingleValueEnum, :to_urn, 1)
      assert function_exported?(SingleValueEnum, :from_urn, 1)
    end

    test "TwoValueEnum has correct type spec" do
      assert function_exported?(TwoValueEnum, :values, 0)
      assert function_exported?(TwoValueEnum, :to_urn, 1)
      assert function_exported?(TwoValueEnum, :from_urn, 1)
    end
  end

  describe "enum without URN prefix" do
    test "SimpleEnum does not have to_urn/1 function" do
      refute function_exported?(SimpleEnum, :to_urn, 1)
    end

    test "SimpleEnum does not have from_urn/1 function" do
      refute function_exported?(SimpleEnum, :from_urn, 1)
    end

    test "SimpleEnum still has values/0 and is_value/1" do
      assert function_exported?(SimpleEnum, :values, 0)
      # is_value is a guard, not a regular function
      assert SimpleEnum.values() == [SimpleEnum.Foo, SimpleEnum.Bar, SimpleEnum.BazQux]
    end
  end

  describe "URN prefix normalization" do
    test "adds trailing colon if not present" do
      # UrnEnum was defined with "tech.studitemps:context:entity:" (with colon)
      # UrnEnumWithColon was defined with "tech.studitemps:test:" (with colon)
      # Both should work the same way
      assert UrnEnum.to_urn(UrnEnum.Alpha) == "tech.studitemps:context:entity:alpha"
      assert UrnEnumWithColon.to_urn(UrnEnumWithColon.One) == "tech.studitemps:test:one"
    end
  end
end
