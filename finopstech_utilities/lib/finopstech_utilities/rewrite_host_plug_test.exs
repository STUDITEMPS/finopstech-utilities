defmodule FinopstechUtilities.RewriteHostPlugTest do
  use ExUnit.Case, async: true
  use Plug.Test

  import Phoenix.ConnTest

  alias FinopstechUtilities.RewriteHostPlug

  setup _tags do
    conn = Phoenix.ConnTest.build_conn()

    {:ok, %{conn: conn}}
  end

  test "rewrites host", %{conn: conn} do
    conn = %{conn | host: "www.thishost.com"}
    conn = conn |> RewriteHostPlug.call(host: "www.anotherhost.com")
    assert redirected_to(conn) == "http://www.anotherhost.com/"
  end

  test "keeps the path", %{conn: conn} do
    conn = %{conn | host: "www.thishost.com", request_path: "/foo/bar/baz"}
    conn = conn |> RewriteHostPlug.call(host: "www.anotherhost.com")
    assert redirected_to(conn) == "http://www.anotherhost.com/foo/bar/baz"
  end

  test "keeps the query params", %{conn: conn} do
    conn = %{
      conn
      | host: "www.thishost.com",
        query_params: %{"foo" => "bar"},
        query_string: "foo=bar"
    }

    conn = conn |> RewriteHostPlug.call(host: "www.anotherhost.com")
    assert redirected_to(conn) == "http://www.anotherhost.com/?foo=bar"
  end
end
