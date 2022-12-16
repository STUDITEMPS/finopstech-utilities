defmodule FinopstechUtilities.SessionPlug do
  @moduledoc """
  Our custom wrapper around `Plug.Session` in order
  to enable loading of session configuration at runtime.
  """

  @default_options [key: :session_options]

  def init(options) do
    Keyword.merge(@default_options, options)
  end

  def call(conn, options) do
    Plug.Session.call(conn, Plug.Session.init(config(options)))
  end

  def config(app: app, key: key) do
    Application.fetch_env!(app, key)
  end
end
