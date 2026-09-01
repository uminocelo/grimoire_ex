defmodule Grimoire.Watcher do
  @moduledoc """
  `GenServer` that polls source files (`:timer.send_interval/2` — no
  native FS event bindings, per the zero-runtime-deps policy) and
  triggers a debounced rebuild when a change is detected. At the default
  300ms poll / 200ms debounce, this is indistinguishable from native
  events for a typical save-and-check workflow.

  Watches `_posts/`, `_pages/`, `_layouts/`, `_includes/`, `assets/`, and
  `config.exs` under the site root. Each file is tracked by a content
  fingerprint (`:erlang.phash2/1` of its bytes), not raw mtime — many
  filesystems only report mtime at one-second resolution, which would
  miss a quick edit-and-save that lands within the same wall-clock
  second.
  """

  use GenServer, restart: :transient

  alias Grimoire.{Builder, Scanner}
  alias Grimoire.CLI.Logger, as: Log

  @watched_dirs ~w(_posts _pages _layouts _includes assets)
  @default_poll_interval 300
  @default_debounce 200

  @type changes :: %{added: [String.t()], modified: [String.t()], deleted: [String.t()]}

  @doc """
  Starts a watcher under `Grimoire.ServeSupervisor`. `opts`: `:site_root`
  (required), `:config` (required), `:site` (an already-scanned
  `%Site{}`, avoids a redundant initial scan), `:poll_interval` (default
  #{@default_poll_interval}ms), `:debounce` (default #{@default_debounce}ms),
  `:on_rebuild` (default calls `Grimoire.Builder.build/1`; overridable,
  mainly for tests), `:name`.
  """
  @spec start(keyword()) :: {:ok, pid()} | {:error, term()}
  def start(opts \\ []) do
    case DynamicSupervisor.start_child(Grimoire.ServeSupervisor, {__MODULE__, opts}) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      other -> other
    end
  end

  @doc "Stops the watcher registered as `name` (default the singleton)."
  @spec stop(GenServer.server()) :: :ok
  def stop(name \\ __MODULE__) do
    if pid = Process.whereis(name) do
      DynamicSupervisor.terminate_child(Grimoire.ServeSupervisor, pid)
    end

    :ok
  end

  @doc false
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc false
  @impl true
  def init(opts) do
    site_root = Keyword.fetch!(opts, :site_root)
    config = Keyword.fetch!(opts, :config)
    site = Keyword.get(opts, :site) || Scanner.scan(site_root, config)
    poll_interval = Keyword.get(opts, :poll_interval, @default_poll_interval)
    debounce = Keyword.get(opts, :debounce, @default_debounce)
    on_rebuild = Keyword.get(opts, :on_rebuild, &Builder.build/1)

    {:ok, _timer_ref} = :timer.send_interval(poll_interval, self(), :poll)

    {:ok,
     %{
       site_root: site_root,
       config: config,
       site: site,
       fingerprints: snapshot_fingerprints(site_root),
       debounce: debounce,
       debounce_ref: nil,
       on_rebuild: on_rebuild
     }}
  end

  @doc false
  @impl true
  def handle_info(:poll, state) do
    new_fingerprints = snapshot_fingerprints(state.site_root)

    case diff(state.fingerprints, new_fingerprints) do
      nil ->
        {:noreply, state}

      changes ->
        if state.debounce_ref, do: Process.cancel_timer(state.debounce_ref)
        ref = Process.send_after(self(), {:rebuild, changes}, state.debounce)
        {:noreply, %{state | fingerprints: new_fingerprints, debounce_ref: ref}}
    end
  end

  def handle_info({:rebuild, changes}, state) do
    start = System.monotonic_time(:millisecond)
    site = Scanner.scan(state.site_root, state.config)
    state.on_rebuild.(site)
    duration = System.monotonic_time(:millisecond) - start

    changed = changes.added ++ changes.modified ++ changes.deleted
    Log.step("Rebuilt in #{duration}ms (#{Enum.join(changed, ", ")})")

    {:noreply, %{state | site: site, debounce_ref: nil}}
  end

  @doc "Compares two source-path → content-fingerprint snapshots. `nil` if unchanged."
  @spec diff(map(), map()) :: changes() | nil
  def diff(old_fingerprints, new_fingerprints) do
    old_keys = MapSet.new(Map.keys(old_fingerprints))
    new_keys = MapSet.new(Map.keys(new_fingerprints))

    added = new_keys |> MapSet.difference(old_keys) |> MapSet.to_list()
    deleted = old_keys |> MapSet.difference(new_keys) |> MapSet.to_list()

    modified =
      old_keys
      |> MapSet.intersection(new_keys)
      |> Enum.filter(&(Map.fetch!(old_fingerprints, &1) != Map.fetch!(new_fingerprints, &1)))

    if added == [] and modified == [] and deleted == [] do
      nil
    else
      %{added: added, modified: modified, deleted: deleted}
    end
  end

  defp snapshot_fingerprints(site_root) do
    @watched_dirs
    |> Enum.flat_map(&walk_files(Path.join(site_root, &1)))
    |> Kernel.++(config_file(site_root))
    |> Map.new(&{&1, fingerprint(&1)})
  end

  defp config_file(site_root) do
    path = Path.join(site_root, "config.exs")
    if File.regular?(path), do: [path], else: []
  end

  defp walk_files(dir) do
    if File.dir?(dir) do
      dir
      |> File.ls!()
      |> Enum.flat_map(fn entry ->
        full = Path.join(dir, entry)

        cond do
          File.dir?(full) -> walk_files(full)
          File.regular?(full) -> [full]
          true -> []
        end
      end)
    else
      []
    end
  end

  defp fingerprint(path) do
    case File.read(path) do
      {:ok, content} -> :erlang.phash2(content)
      {:error, _reason} -> nil
    end
  end
end
