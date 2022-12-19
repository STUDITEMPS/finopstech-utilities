defmodule FinopstechUtilities.SessionPlug do
  @moduledoc """
  Our custom wrapper around `Plug.Session` in order
  to enable loading of session configuration at runtime.

  The options are `app` and `key` that point to the configured session
  options defined here: https://hexdocs.pm/plug/Plug.Session.html
  """

  @type option :: {:app, atom()} | {:key, atom()}
  @type options :: [option]

  @spec init(options) :: options
  def init(options) do
    options
  end

  def call(conn, options) do
    Plug.Session.call(conn, Plug.Session.init(config(options)))
  end

  def config(app: app, key: key) do
    Application.fetch_env!(app, key)
  end
end
