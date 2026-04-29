defmodule Diffmate.CLI do
  @options []
  @usage_message "Usage: diffmate <path-to-DIFFMATE.md | project-dir>"

  def main(args) do
    :io.setopts(:user, encoding: :unicode)

    case evaluate(args) do
      :ok ->
        wait_for_shutdown()

      {:error, message} ->
        IO.puts(:stderr, message)
        System.halt(1)
    end
  end

  defp evaluate(args) do
    case OptionParser.parse(args, strict: @options) do
      {_opts, [path], []} -> run(path)
      _ -> {:error, @usage_message}
    end
  end

  defp run(path) do
    config_path = resolve_config_path(path)
    Process.flag(:trap_exit, true)

    with :ok <- Diffmate.Config.set_config_file(config_path),
         {:ok, _config} <- Diffmate.Config.parse(config_path),
         {:ok, _} <- Application.ensure_all_started(:phoenix_pubsub),
         {:ok, _pid} <- Diffmate.Application.start(:normal, []) do
      start_stdin_reader()
      :ok
    else
      {:error, reason} ->
        {:error, "Failed to start: #{format_reason(reason)}"}
    end
  end

  defp resolve_config_path(input) do
    base_dir =
      case System.get_env("DIFFMATE_CALLER_CWD") do
        nil -> File.cwd!()
        "" -> File.cwd!()
        cwd -> cwd
      end

    expanded = Path.expand(input, base_dir)
    if File.dir?(expanded), do: Path.join(expanded, "DIFFMATE.md"), else: expanded
  end

  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason), do: inspect(reason)

  defp wait_for_shutdown do
    case Process.whereis(Diffmate.Supervisor) do
      nil ->
        IO.puts(:stderr, "Diffmate supervisor is not running")
        System.halt(1)

      pid ->
        ref = Process.monitor(pid)
        do_wait(ref, pid)
    end
  end

  defp do_wait(ref, pid) do
    receive do
      {:DOWN, ^ref, :process, ^pid, :normal} -> System.halt(0)
      {:DOWN, ^ref, :process, ^pid, _reason} -> System.halt(1)
      _other -> do_wait(ref, pid)
    end
  end

  defp start_stdin_reader do
    spawn_link(fn -> read_stdin() end)
    :ok
  end

  defp read_stdin do
    case IO.gets("") do
      :eof ->
        :ok

      {:error, _} ->
        :ok

      line ->
        text = String.trim(line)

        cond do
          text == "/clear" ->
            Phoenix.PubSub.broadcast(Diffmate.PubSub, "diffmate:events", {:user_clear, %{}})

          text == "/compact" ->
            Phoenix.PubSub.broadcast(Diffmate.PubSub, "diffmate:events", {:user_compact, %{}})

          text != "" ->
            Phoenix.PubSub.broadcast(
              Diffmate.PubSub,
              "diffmate:events",
              {:user_message, %{text: text}}
            )

          true ->
            :ok
        end

        read_stdin()
    end
  end
end
