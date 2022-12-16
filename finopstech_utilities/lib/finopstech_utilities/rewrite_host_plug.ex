defmodule FinopstechUtilities.RewriteHostPlug do
  @moduledoc """
  We use this plug to redirect from alternative domains to our current one.
  Namely we redirect from .studitemps.tech to jobvalley.tech
  """

  @doc """
  Init is not in use as this plug is meant to be configurable at runtime.
  """
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

  defp rewritten_url(
         %Plug.Conn{
           scheme: scheme,
           port: port,
           request_path: path,
           query_string: ""
         },
         host
       ) do
    %URI{
      host: host,
      path: path,
      port: port,
      scheme: to_string(scheme)
    }
    |> URI.to_string()
  end

  defp rewritten_url(
         %Plug.Conn{
           scheme: scheme,
           port: port,
           request_path: path,
           query_string: query_string
         },
         host
       ) do
    %URI{
      host: host,
      path: path,
      port: port,
      query: query_string,
      scheme: to_string(scheme)
    }
    |> URI.to_string()
  end

  defp configured_host(app: app, key: key) do
    Application.fetch_env!(app, key)
    |> get_in([:url, :host])
  end
end
