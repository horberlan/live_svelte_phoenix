defmodule LiveSveltePheonixWeb.SessionLiveLogger do
  @moduledoc """
  Conditional logging helper for SessionLive.
  Logs are only output in development environment.
  """

  require Logger

  @doc """
  Logs a debug message only in development environment.
  In production, uses Logger.debug which can be configured.
  """
  def debug(message) do
    if Mix.env() == :dev do
      IO.puts(message)
    else
      Logger.debug(message)
    end
  end

  @doc """
  Logs an info message.
  """
  def info(message) do
    Logger.info(message)
  end

  @doc """
  Logs a warning message.
  """
  def warn(message) do
    Logger.warning(message)
  end

  @doc """
  Logs an error message.
  """
  def error(message) do
    Logger.error(message)
  end
end
