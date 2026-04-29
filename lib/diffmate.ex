defmodule Diffmate do
  @moduledoc false
end

defmodule Diffmate.Application do
  def start(_type, _args) do
    path = Diffmate.Config.config_file_path()

    case Diffmate.Config.parse(path) do
      {:ok, _config} ->
        children = [
          {Phoenix.PubSub, name: Diffmate.PubSub},
          Diffmate.ConfigWatcher,
          Diffmate.DiffWatch.Supervisor
        ]

        Supervisor.start_link(children, strategy: :one_for_one, name: Diffmate.Supervisor)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
