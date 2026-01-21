defmodule Shared.EitherTest do
  @moduledoc false

  use ExUnit.Case

  alias Shared.Either

  describe "return/1" do
    test "wraps value in ok tuple" do
      assert Either.return("value") == {:ok, "value"}
      assert Either.return(123) == {:ok, 123}
      assert Either.return(nil) == {:ok, nil}
    end
  end

  describe "guards" do
    test "is_left? returns true for error tuples" do
      require Either
      assert Either.is_left?({:error, :reason})
      assert Either.is_left?({:error, "message"})
    end

    test "is_left? returns false for ok tuples" do
      require Either
      refute Either.is_left?({:ok, "value"})
    end

    test "is_right? returns true for ok tuples" do
      require Either
      assert Either.is_right?({:ok, "value"})
      assert Either.is_right?({:ok, nil})
    end

    test "is_right? returns false for error tuples" do
      require Either
      refute Either.is_right?({:error, :reason})
    end

    test "is_either? returns true for both ok and error tuples" do
      require Either
      assert Either.is_either?({:ok, "value"})
      assert Either.is_either?({:error, :reason})
    end
  end

  describe "flatten/1" do
    test "flattens nested ok tuple" do
      assert Either.flatten({:ok, {:ok, "value"}}) == {:ok, "value"}
      assert Either.flatten({:ok, {:error, :reason}}) == {:error, :reason}
    end

    test "passes through error" do
      assert Either.flatten({:error, :outer}) == {:error, :outer}
    end
  end

  describe "map/2" do
    test "applies function to ok value" do
      assert Either.map({:ok, 5}, &(&1 * 2)) == {:ok, 10}
      assert Either.map({:ok, "hello"}, &String.upcase/1) == {:ok, "HELLO"}
    end

    test "passes through error unchanged" do
      assert Either.map({:error, :reason}, &(&1 * 2)) == {:error, :reason}
    end
  end

  describe "map_list/2" do
    test "maps function over list in ok tuple" do
      assert Either.map_list({:ok, [1, 2, 3]}, &(&1 * 2)) == {:ok, [2, 4, 6]}
    end

    test "passes through error unchanged" do
      assert Either.map_list({:error, :reason}, &(&1 * 2)) == {:error, :reason}
    end
  end

  describe "flat_map/2" do
    test "applies function and flattens result" do
      result = Either.flat_map({:ok, 5}, fn x -> {:ok, x * 2} end)
      assert result == {:ok, 10}
    end

    test "propagates error from original either" do
      result = Either.flat_map({:error, :original}, fn x -> {:ok, x * 2} end)
      assert result == {:error, :original}
    end

    test "propagates error from function result" do
      result = Either.flat_map({:ok, 5}, fn _ -> {:error, :from_function} end)
      assert result == {:error, :from_function}
    end
  end

  describe "flat_map_list/2" do
    test "flat maps over list and sequences results" do
      result = Either.flat_map_list({:ok, [1, 2, 3]}, fn x -> {:ok, x * 2} end)
      assert result == {:ok, [2, 4, 6]}
    end

    test "returns first error encountered" do
      result =
        Either.flat_map_list({:ok, [1, 2, 3]}, fn
          2 -> {:error, :two_is_bad}
          x -> {:ok, x}
        end)

      assert result == {:error, :two_is_bad}
    end

    test "passes through error unchanged" do
      result = Either.flat_map_list({:error, :reason}, fn x -> {:ok, x} end)
      assert result == {:error, :reason}
    end
  end

  describe "sequence/1" do
    test "converts list of oks to ok of list" do
      assert Either.sequence([{:ok, 1}, {:ok, 2}, {:ok, 3}]) == {:ok, [1, 2, 3]}
    end

    test "returns first error encountered" do
      assert Either.sequence([{:ok, 1}, {:error, :bad}, {:ok, 3}]) == {:error, :bad}
    end

    test "handles empty list" do
      assert Either.sequence([]) == {:ok, []}
    end
  end

  describe "traverse/2" do
    test "applies function to each element and collects results" do
      result = Either.traverse([1, 2, 3], fn x -> {:ok, x * 2} end)
      assert result == {:ok, [2, 4, 6]}
    end

    test "stops at first error" do
      result =
        Either.traverse([1, 2, 3], fn
          2 -> {:error, :two_is_bad}
          x -> {:ok, x}
        end)

      assert result == {:error, :two_is_bad}
    end

    test "handles empty list" do
      assert Either.traverse([], fn x -> {:ok, x} end) == {:ok, []}
    end
  end

  describe "fold/3" do
    test "applies if_ok function for ok tuple" do
      result = Either.fold({:ok, 5}, fn _ -> :was_error end, fn x -> x * 2 end)
      assert result == 10
    end

    test "applies if_error function for error tuple" do
      result = Either.fold({:error, :reason}, fn e -> {:failed, e} end, fn x -> x * 2 end)
      assert result == {:failed, :reason}
    end
  end

  describe "ok_or_error/1" do
    test "returns :ok for ok tuple" do
      assert Either.ok_or_error({:ok, "any value"}) == :ok
      assert Either.ok_or_error({:ok, nil}) == :ok
    end

    test "returns error tuple for error" do
      assert Either.ok_or_error({:error, :reason}) == {:error, :reason}
      assert Either.ok_or_error({:error, "message"}) == {:error, "message"}
    end
  end
end
