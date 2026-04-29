defmodule Diffmate.DiffWatch.RunnerTest do
  use ExUnit.Case

  alias Diffmate.DiffWatch.Runner

  test "command approval decision rejects non-always policies" do
    assert Runner.command_approval_decision("never") == "reject"
    assert Runner.command_approval_decision("on-request") == "reject"
    assert Runner.command_approval_decision("on-failure") == "reject"
  end

  test "command approval decision accepts only always policy" do
    assert Runner.command_approval_decision("always") == "acceptForSession"
  end

  test "legacy approval decision rejects non-always policies" do
    assert Runner.legacy_approval_decision("never") == "denied"
    assert Runner.legacy_approval_decision("on-request") == "denied"
    assert Runner.legacy_approval_decision("on-failure") == "denied"
  end

  test "legacy approval decision accepts only always policy" do
    assert Runner.legacy_approval_decision("always") == "approved_for_session"
  end
end
