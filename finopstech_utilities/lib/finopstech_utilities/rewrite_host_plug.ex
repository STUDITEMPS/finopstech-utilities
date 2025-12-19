defmodule FinopstechUtilities.RewriteHostPlug do
  @moduledoc """
  We use this plug to redirect from alternative domains to our current one.
  Namely we redirect from .studitemps.tech to jobvalley.tech.

  The options are `app` and `key` that point to the Phoenix.Endpoint configuration:
  https://hexdocs.pm/phoenix/Phoenix.Endpoint.html#module-endpoint-configuration
  """

  @type option :: {:app, atom()} | {:key, atom()}
  @type options :: [option]

  @spec init(options) :: options
  def init(options) do
    options
  end

  def call(%Plug.Conn{host: host} = conn, options) do
    configured_host = Keyword.get_lazy(options, :host, fn -> configured_host(options) end)

    case host do
      ^configured_host ->
        conn

      _ ->
        conn
        |> Phoenix.Controller.redirect(external: rewritten_url(conn, configured_host))
        |> Plug.Conn.halt()
    end
  end

  defp rewritten_url(%Plug.Conn{scheme: scheme, port: port, request_path: path, query_string: ""}, host) do
    URI.to_string(%URI{host: host, path: path, port: port, scheme: to_string(scheme)})
  end

  defp rewritten_url(%Plug.Conn{scheme: scheme, port: port, request_path: path, query_string: query_string}, host) do
    URI.to_string(%URI{host: host, path: path, port: port, query: query_string, scheme: to_string(scheme)})
  end

  defp configured_host(app: app, key: key) do
    app
    |> Application.fetch_env!(key)
    |> get_in([:url, :host])
  end
end
