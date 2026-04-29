defmodule Diffmate.DiffWatch.Poller do
  @moduledoc """
  Polls git diff and broadcasts changes.
  """

  use GenServer
  require Logger

  alias Diffmate.DiffWatch.Delta
  alias Diffmate.DiffWatch.DiffSource

  @topic "diffmate:events"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_config do
    GenServer.call(__MODULE__, :get_config)
  end

  @impl true
  def init(_opts) do
    Phoenix.PubSub.subscribe(Diffmate.PubSub, @topic)
    config = Diffmate.ConfigWatcher.get_config()
    config_path = Diffmate.Config.config_file_path()
    schedule_poll(0)

    {:ok,
     %{
       config_path: config_path,
       config: config,
       prev_diff_hash: nil,
       prev_diff_empty: true,
       prev_diff: ""
     }}
  end

  @impl true
  def handle_call(:get_config, _from, state) do
    {:reply, state.config, state}
  end

  @impl true
  def handle_info(:poll, state) do
    state = check_diff(state)
    schedule_poll(state.config.poll_interval)
    {:noreply, state}
  end

  @impl true
  def handle_info({:config_changed, %{config: new_config}}, state) do
    {:noreply, %{state | config: new_config}}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  defp check_diff(state) do
    cwd = Path.dirname(state.config_path)

    case DiffSource.run(state.config.diff_command, cwd, state.config.include_untracked) do
      {:ok, diff} ->
        handle_diff(state, diff)

      {:error, reason} ->
        Logger.warning("[Diffmate.Poller] #{reason}")
        state
    end
  end

  defp handle_diff(state, diff) do
    new_hash = :crypto.hash(:sha256, diff) |> Base.encode16()

    if new_hash == state.prev_diff_hash do
      state
    else
      new_empty = diff == ""

      cond do
        new_empty ->
          broadcast(:context_reset, %{prompt: state.config.prompt})

        state.prev_diff_empty ->
          broadcast(:diff_started, %{prompt: state.config.prompt, diff: diff})

        true ->
          delta = Delta.diff_delta(state.prev_diff, diff)
          if delta != "", do: broadcast(:diff_changed, %{diff: delta})
      end

      %{state | prev_diff_hash: new_hash, prev_diff_empty: new_empty, prev_diff: diff}
    end
  end

  defp schedule_poll(interval) do
    Process.send_after(self(), :poll, interval)
  end

  defp broadcast(event, payload) do
    Phoenix.PubSub.broadcast(Diffmate.PubSub, @topic, {event, payload})
  end
end
