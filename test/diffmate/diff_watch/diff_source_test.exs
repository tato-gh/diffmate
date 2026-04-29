defmodule Diffmate.DiffWatch.DiffSourceTest do
  use ExUnit.Case

  alias Diffmate.DiffWatch.DiffSource

  defp tmp_dir do
    path = Path.join(System.tmp_dir!(), "diffmate_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(path)
    path
  end

  test "run/3 returns filtered diff on successful diff command" do
    cwd = System.tmp_dir!()

    assert {:ok, diff} = DiffSource.run("printf 'diff --git a/lib/a.ex b/lib/a.ex\n'", cwd, false)
    assert diff =~ "diff --git a/lib/a.ex b/lib/a.ex"
  end

  test "run/3 returns error on failed diff command" do
    cwd = System.tmp_dir!()

    assert {:error, reason} = DiffSource.run("echo broken && exit 7", cwd, false)
    assert reason =~ "status 7"
    assert reason =~ "broken"
  end

  test "run/3 includes untracked files when include_untracked is true" do
    cwd = tmp_dir()
    System.cmd("git", ["init"], cd: cwd)
    System.cmd("git", ["config", "user.email", "diffmate@example.test"], cd: cwd)
    System.cmd("git", ["config", "user.name", "Diffmate Test"], cd: cwd)
    File.write!(Path.join(cwd, "README.md"), "base\n")
    System.cmd("git", ["add", "README.md"], cd: cwd)
    System.cmd("git", ["commit", "-m", "init"], cd: cwd)

    File.write!(Path.join(cwd, "new_file.txt"), "hello\n")

    assert {:ok, diff} = DiffSource.run("git diff HEAD", cwd, true)
    assert diff =~ "diff --git a/new_file.txt b/new_file.txt"
    assert diff =~ "+hello"
  end

  test "filter_config_diff/1 removes DIFFMATE.md section but keeps other files" do
    diff = """
    diff --git a/DIFFMATE.md b/DIFFMATE.md
    --- a/DIFFMATE.md
    +++ b/DIFFMATE.md
    @@ -1 +1 @@
    -old
    +new
    diff --git a/lib/a.ex b/lib/a.ex
    --- a/lib/a.ex
    +++ b/lib/a.ex
    @@ -1 +1,2 @@
     old
    +new
    """

    filtered = DiffSource.filter_config_diff(diff)
    refute filtered =~ "DIFFMATE.md"
    assert filtered =~ "diff --git a/lib/a.ex b/lib/a.ex"
    assert filtered =~ "+new"
  end
end
