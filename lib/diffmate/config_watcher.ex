defmodule Diffmate.ConfigWatcher do
  @moduledoc """
  Watches DIFFMATE.md and broadcasts meaningful config changes.
  """

  use GenServer
  require Logger

  @topic "diffmate:events"
  @poll_interval 1000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_config do
    GenServer.call(__MODULE__, :get_config)
  end

  @impl true
  def init(_opts) do
    path = Diffmate.Config.config_file_path()
    mtime = read_mtime(path)

    case Diffmate.Config.parse(path) do
      {:ok, config} ->
        schedule_poll()
        {:ok, %{path: path, mtime: mtime, config: config}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:get_config, _from, state) do
    {:reply, state.config, state}
  end

  @impl true
  def handle_info(:poll, state) do
    state = check_config(state)
    schedule_poll()
    {:noreply, state}
  end

  defp check_config(state) do
    new_mtime = read_mtime(state.path)

    if new_mtime == state.mtime do
      state
    else
      case Diffmate.Config.parse(state.path) do
        {:error, reason} ->
          Logger.warning("Failed to reload DIFFMATE.md: #{reason}")
          %{state | mtime: new_mtime}

        {:ok, new_config} ->
          broadcast_changes(state.config, new_config)
          %{state | config: new_config, mtime: new_mtime}
      end
    end
  end

  defp broadcast_changes(old, new) do
    if runtime_config_changed?(old, new) do
      broadcast(:config_changed, %{config: new})
    end

    if old.prompt != new.prompt do
      broadcast(:prompt_changed, %{prompt: new.prompt})
    end
  end

  defp runtime_config_changed?(old, new) do
    old.command != new.command or
      old.diff_command != new.diff_command or
      old.poll_interval != new.poll_interval or
      old.include_untracked != new.include_untracked or
      old.approval_policy != new.approval_policy or
      old.thread_sandbox != new.thread_sandbox or
      old.turn_sandbox_policy != new.turn_sandbox_policy
  end

  defp schedule_poll do
    Process.send_after(self(), :poll, @poll_interval)
  end

  defp read_mtime(path) do
    case File.stat(path) do
      {:ok, %{mtime: mtime}} -> mtime
      _ -> nil
    end
  end

  defp broadcast(event, payload) do
    Phoenix.PubSub.broadcast(Diffmate.PubSub, @topic, {event, payload})
  end
end
