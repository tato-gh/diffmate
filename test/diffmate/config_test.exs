defmodule Diffmate.ConfigTest do
  use ExUnit.Case

  defp write_tmp(content) do
    path = Path.join(System.tmp_dir!(), "diffmate_#{:erlang.unique_integer([:positive])}.md")
    File.write!(path, content)
    path
  end

  test "parse/1 with minimal valid YAML front-matter" do
    path =
      write_tmp("""
      ---
      ---
      """)

    assert {:ok, config} = Diffmate.Config.parse(path)
    assert config.command == "codex app-server"
    assert config.diff_command == "git diff HEAD"
    assert config.poll_interval == 1000
    assert config.include_untracked == false
    assert config.approval_policy == "never"
    assert config.thread_sandbox == "read-only"
    assert config.turn_sandbox_policy == %{"type" => "readOnly", "networkAccess" => false}
    assert config.prompt == ""
  end

  test "parse/1 builds config from YAML" do
    path =
      write_tmp("""
      ---
      command: "codex custom"
      diff_command: "git diff --cached"
      poll_interval: 500
      include_untracked: true
      approval_policy: "on-request"
      thread_sandbox: "workspace-write"
      turn_sandbox_policy:
        type: "workspaceWrite"
        writableRoots: ["/tmp/example"]
        networkAccess: false
      prompt: "review this diff"
      ---
      """)

    assert {:ok, config} = Diffmate.Config.parse(path)
    assert config.command == "codex custom"
    assert config.diff_command == "git diff --cached"
    assert config.poll_interval == 500
    assert config.include_untracked == true
    assert config.approval_policy == "on-request"
    assert config.thread_sandbox == "workspace-write"

    assert config.turn_sandbox_policy == %{
             "type" => "workspaceWrite",
             "writableRoots" => ["/tmp/example"],
             "networkAccess" => false
           }

    assert config.prompt == "review this diff"
  end

  test "parse/1 returns default config when file does not exist" do
    assert {:ok, config} = Diffmate.Config.parse("/nonexistent/path/DIFFMATE.md")
    assert config.command == "codex app-server"
    assert config.diff_command == "git diff HEAD"
  end

  test "parse/1 returns error when front-matter is missing" do
    path = write_tmp("just plain text without front-matter\n")
    assert {:error, msg} = Diffmate.Config.parse(path)
    assert msg =~ "front-matter"
  end

  test "parse/1 returns error on invalid YAML" do
    path =
      write_tmp("""
      ---
      invalid: yaml: [broken
      ---
      """)

    assert {:error, msg} = Diffmate.Config.parse(path)
    assert msg =~ "Failed to parse YAML"
  end

  test "parse/1 accepts body text after front-matter" do
    path =
      write_tmp("""
      ---
      prompt: "hello"
      ---
      This body text is ignored.
      """)

    assert {:ok, config} = Diffmate.Config.parse(path)
    assert config.prompt == "hello"
  end
end
