defmodule LibOss.Debug do
  @moduledoc """
  Debug tools with environment-based conditional compilation
  """
  require Logger

  # 运行时环境检查
  defp debug_enabled? do
    case System.get_env("MIX_ENV") do
      env when env in ["dev", "test"] -> true
      # 默认启用调试（开发环境）
      nil -> true
      # 生产环境禁用
      _ -> false
    end
  end

  @debug_prefix "[LibOss.Debug]"

  def debug(msg) do
    if debug_enabled?() do
      tap(msg, fn msg ->
        Logger.debug("#{@debug_prefix} => #{inspect(msg)}")
      end)
    else
      msg
    end
  end

  def stacktrace(msg) do
    if debug_enabled?() do
      tap(msg, fn msg ->
        stacktrace_info =
          self()
          |> Process.info(:current_stacktrace)
          |> then(fn {:current_stacktrace, stacktrace} -> stacktrace end)
          # ignore the first two stacktrace
          |> Enum.drop(2)
          |> Enum.map_join("\n", fn {mod, fun, arity, [file: file, line: line]} ->
            "\t#{mod}.#{fun}/#{arity} #{file}:#{line}"
          end)

        Logger.debug("#{@debug_prefix} => #{inspect(msg)} \n#{stacktrace_info}")
      end)
    else
      msg
    end
  end

  def enabled?, do: debug_enabled?()
end
