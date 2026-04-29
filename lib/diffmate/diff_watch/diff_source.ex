defmodule Diffmate.DiffWatch.DiffSource do
  @moduledoc """
  Reads git diff output and filters Diffmate's own config changes.
  """

  def run(diff_command, cwd, include_untracked) do
    with {:ok, tracked} <- run_shell(diff_command <> " -- .", cwd),
         {:ok, untracked} <- maybe_run_untracked(cwd, include_untracked) do
      {:ok, filter_config_diff(tracked <> untracked)}
    end
  end

  defp maybe_run_untracked(cwd, true), do: run_untracked_shell(cwd)
  defp maybe_run_untracked(_cwd, false), do: {:ok, ""}

  defp run_shell(command, cwd) do
    case System.cmd("sh", ["-c", command], cd: cwd, stderr_to_stdout: true) do
      {out, 0} ->
        {:ok, out}

      {out, status} ->
        {:error, "diff command failed with status #{status}: #{String.trim(out)}"}
    end
  end

  defp run_untracked_shell(cwd) do
    with {:ok, files} <- untracked_files(cwd) do
      files
      |> Enum.map(&untracked_file_diff(cwd, &1))
      |> collect_untracked_diffs()
    end
  end

  defp untracked_files(cwd) do
    case System.cmd("git", ["ls-files", "-z", "--others", "--exclude-standard", "--", "."],
           cd: cwd,
           stderr_to_stdout: true
         ) do
      {out, 0} ->
        files =
          out
          |> String.split(<<0>>, trim: true)
          |> Enum.reject(&(&1 == "DIFFMATE.md"))

        {:ok, files}

      {out, status} ->
        {:error, "untracked file listing failed with status #{status}: #{String.trim(out)}"}
    end
  end

  defp untracked_file_diff(cwd, file) do
    case System.cmd("git", ["diff", "--no-index", "--", "/dev/null", file],
           cd: cwd,
           stderr_to_stdout: false
         ) do
      {out, status} when status in [0, 1] ->
        {:ok, out}

      {_out, status} ->
        {:error, "untracked diff command failed for #{file} with status #{status}"}
    end
  end

  defp collect_untracked_diffs(results) do
    Enum.reduce_while(results, {:ok, ""}, fn
      {:ok, diff}, {:ok, acc} ->
        {:cont, {:ok, acc <> diff}}

      {:error, reason}, _acc ->
        {:halt, {:error, reason}}
    end)
  end

  def filter_config_diff(diff_output) do
    {kept, _} =
      diff_output
      |> String.split("\n")
      |> Enum.reduce({[], false}, &filter_line/2)

    kept |> Enum.reverse() |> Enum.join("\n")
  end

  defp filter_line("diff --git" <> _ = line, {acc, _skip}) do
    skip = String.contains?(line, "DIFFMATE.md")
    {if(skip, do: acc, else: [line | acc]), skip}
  end

  defp filter_line(_line, {acc, true}), do: {acc, true}
  defp filter_line(line, {acc, false}), do: {[line | acc], false}
end
