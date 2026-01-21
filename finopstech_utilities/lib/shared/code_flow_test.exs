defmodule Shared.CodeFlowTest do
  @moduledoc false

  use ExUnit.Case

  alias Shared.CodeFlow

  describe "ok/1" do
    test "wraps value in ok tuple" do
      assert CodeFlow.ok("value") == {:ok, "value"}
      assert CodeFlow.ok(123) == {:ok, 123}
      assert CodeFlow.ok(nil) == {:ok, nil}
      assert CodeFlow.ok(%{key: "value"}) == {:ok, %{key: "value"}}
    end
  end

  describe "noreply/1" do
    test "wraps value in noreply tuple" do
      assert CodeFlow.noreply(%{state: 1}) == {:noreply, %{state: 1}}
      assert CodeFlow.noreply([]) == {:noreply, []}
    end
  end

  describe "success_value/1" do
    test "extracts value from ok tuple" do
      assert CodeFlow.success_value({:ok, "value"}) == "value"
      assert CodeFlow.success_value({:ok, 123}) == 123
      assert CodeFlow.success_value({:ok, nil}) == nil
    end
  end

  describe "status/1" do
    test "returns status atom from tuple" do
      assert CodeFlow.status({:ok, "value"}) == :ok
      assert CodeFlow.status({:error, "reason"}) == :error
      assert CodeFlow.status({:noreply, %{}}) == :noreply
      assert CodeFlow.status({:custom, nil}) == :custom
    end
  end

  describe "successful_if/2" do
    test "returns :ok for :ok result" do
      assert CodeFlow.successful_if(:ok, :any_condition) == :ok
    end

    test "returns :ok for {:ok, _} result" do
      assert CodeFlow.successful_if({:ok, "value"}, :any_condition) == :ok
      assert CodeFlow.successful_if({:ok, nil}, :ignored) == :ok
    end

    test "returns :ok when error matches condition" do
      assert CodeFlow.successful_if({:error, :not_found}, :not_found) == :ok
      assert CodeFlow.successful_if({:error, :expired}, :expired) == :ok
    end

    test "returns error when error does not match condition" do
      assert CodeFlow.successful_if({:error, :unauthorized}, :not_found) ==
               {:error, :unauthorized}
    end

    test "returns :ok when error matches any condition in list" do
      assert CodeFlow.successful_if({:error, :not_found}, [:not_found, :expired]) == :ok
      assert CodeFlow.successful_if({:error, :expired}, [:not_found, :expired]) == :ok
    end

    test "returns error when error does not match any condition in list" do
      assert CodeFlow.successful_if({:error, :unauthorized}, [:not_found, :expired]) ==
               {:error, :unauthorized}
    end

    test "returns original result for other values" do
      assert CodeFlow.successful_if({:custom, "data"}, :ignored) == {:custom, "data"}
      assert CodeFlow.successful_if("string", :ignored) == "string"
    end
  end
end
