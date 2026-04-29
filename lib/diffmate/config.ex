defmodule Diffmate.Config do
  @moduledoc """
  Loads Diffmate configuration from DIFFMATE.md.
  """

  @default_config %{
    command: "codex app-server",
    diff_command: "git diff HEAD",
    poll_interval: 1000,
    include_untracked: false,
    approval_policy: "never",
    thread_sandbox: "read-only",
    turn_sandbox_policy: %{
      "type" => "readOnly",
      "networkAccess" => false
    },
    prompt: ""
  }

  def config_file_path do
    Application.get_env(:diffmate, :config_file_path)
  end

  def set_config_file(path) when is_binary(path) do
    Application.put_env(:diffmate, :config_file_path, path)
    :ok
  end

  def parse(path) do
    case File.read(path) do
      {:error, :enoent} -> {:ok, @default_config}
      {:error, reason} -> {:error, "Failed to read DIFFMATE.md: #{inspect(reason)}"}
      {:ok, content} -> parse_content(content)
    end
  end

  defp parse_content(content) do
    case String.split(content, "---\n", parts: 3) do
      ["", fm, _body] ->
        case YamlElixir.read_from_string(fm) do
          {:ok, yaml} when is_map(yaml) -> {:ok, build_config(yaml)}
          {:ok, nil} -> {:ok, @default_config}
          {:ok, _} -> {:error, "DIFFMATE.md front-matter must be a map"}
          {:error, reason} -> {:error, "Failed to parse YAML: #{inspect(reason)}"}
        end

      _ ->
        {:error, "DIFFMATE.md must have YAML front-matter (--- ... ---)"}
    end
  end

  defp build_config(yaml) do
    %{
      command: Map.get(yaml, "command", @default_config.command),
      diff_command: Map.get(yaml, "diff_command", @default_config.diff_command),
      poll_interval: Map.get(yaml, "poll_interval", @default_config.poll_interval),
      include_untracked: Map.get(yaml, "include_untracked", @default_config.include_untracked),
      approval_policy: Map.get(yaml, "approval_policy", @default_config.approval_policy),
      thread_sandbox: Map.get(yaml, "thread_sandbox", @default_config.thread_sandbox),
      turn_sandbox_policy:
        Map.get(yaml, "turn_sandbox_policy", @default_config.turn_sandbox_policy),
      prompt: Map.get(yaml, "prompt", @default_config.prompt)
    }
  end
end
