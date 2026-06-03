defmodule FinopstechUtilities.ModulesTest do
  @moduledoc false

  use ExUnit.Case

  import FinopstechUtilities.Modules

  defmodule My.EventListener do
    @moduledoc false
    use FinopstechUtilities.Modules, group: :listener
  end

  defmodule Test.EventListener do
    @moduledoc false
    use FinopstechUtilities.Modules,
      group: {:listener, env: :dev},
      group: {:listener, env: :test}
  end

  describe "get_markers/1" do
    test "returns the keyword list given when using Module Groups" do
      assert [group: :listener] = get_markers(My.EventListener)

      assert [group: {:listener, env: :dev}, group: {:listener, env: :test}] =
               get_markers(Test.EventListener)
    end
  end

  describe "matches?/2" do
    test "detects if a Module has matching criteria" do
      assert matches?(My.EventListener, group: :listener)
      refute matches?(My.EventListener, group: {:listener, env: :test})

      assert matches?(Test.EventListener, group: {:listener, env: :test})
      assert matches?(Test.EventListener, group: {:listener, env: :dev})
      refute matches?(Test.EventListener, group: :listener)
    end

    test "detects whether a Module lives in the given namespace for :in_namespace" do
      assert matches?(My.EventListener, in_namespace: My)
      refute matches?(My.EventListener, in_namespace: Test)

      # the namespace module itself does not lie within its own namespace
      refute matches?(Foo, in_namespace: Foo)

      # a partial name segment is not a namespace match
      refute matches?(FooBar.Listener, in_namespace: Foo)
    end
  end

  describe "find/2" do
    @modules [My.EventListener, Test.EventListener]
    test "detects if a Module has matching criteria" do
      assert [My.EventListener] = find(@modules, group: :listener)

      assert [Test.EventListener] = find(@modules, group: {:listener, env: :dev})
      assert [Test.EventListener] = find(@modules, group: {:listener, env: :test})

      assert [] = find(@modules, group: {:listener, env: :prod})
    end

    test "returns all modules nested below the given namespace" do
      assert [My.EventListener] = find(@modules, in_namespace: My)
      assert [Test.EventListener] = find(@modules, in_namespace: Test)
    end
  end
end
