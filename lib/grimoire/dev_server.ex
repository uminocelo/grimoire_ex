defmodule Grimoire.DevServer do
  @moduledoc """
  `GenServer` wrapping Erlang's built-in `:inets` HTTP server (`httpd`) to
  serve `_site/` during local development.

  `:inets` `httpd` is **not production-grade** — it exists in every OTP
  install with zero extra dependencies, which is exactly what makes it
  the right tool for a `mix grimoire.serve` preview server. Never use it
  to serve a real, public site.

  Only one instance runs under `mix grimoire.serve` at a time, addressed
  by the default name (`Grimoire.DevServer`) via `start/1`, `stop/0`, and
  `port/0`. Pass `:name` in `opts` to run additional instances (mainly
  useful for tests).
  """

  use GenServer, restart: :transient

  alias Grimoire.CLI.Logger, as: Log

  @default_port 4000
  @max_port_offset 10

  @doc """
  Starts a dev server under `Grimoire.ServeSupervisor`. `opts`:
  `:document_root` (default `"_site"`), `:port` (default `4000`, falling
  back through `4001`...`4010` on `:eaddrinuse`), `:name` (default
  `#{inspect(__MODULE__)}`).
  """
  @spec start(keyword()) :: {:ok, pid()} | {:error, term()}
  def start(opts \\ []) do
    case DynamicSupervisor.start_child(Grimoire.ServeSupervisor, {__MODULE__, opts}) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      other -> other
    end
  end

  @doc "Stops the dev server registered as `name` (default the singleton)."
  @spec stop(GenServer.server()) :: :ok
  def stop(name \\ __MODULE__) do
    case Process.whereis(name) || name do
      pid when is_pid(pid) ->
        DynamicSupervisor.terminate_child(Grimoire.ServeSupervisor, pid)
        Log.success("Server stopped.")
        :ok

      _not_running ->
        :ok
    end
  end

  @doc "Returns the port `name` (default the singleton) is actually bound to, or `nil`."
  @spec port(GenServer.server()) :: pos_integer() | nil
  def port(name \\ __MODULE__) do
    if pid = Process.whereis(name) do
      GenServer.call(pid, :port)
    end
  end

  @doc false
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc false
  @impl true
  def init(opts) do
    document_root = Keyword.get(opts, :document_root, "_site")
    start_port = Keyword.get(opts, :port, @default_port)
    max_port = start_port + @max_port_offset

    case start_httpd(document_root, start_port, max_port) do
      {:ok, httpd_pid, bound_port} ->
        Log.success("Dev server running at http://localhost:#{bound_port}")
        Log.step("Press Ctrl+C to stop.")
        {:ok, %{httpd_pid: httpd_pid, port: bound_port, document_root: document_root}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @doc false
  @impl true
  def handle_call(:port, _from, state), do: {:reply, state.port, state}

  @doc false
  @impl true
  def terminate(_reason, state) do
    :inets.stop(:httpd, state.httpd_pid)
    :ok
  end

  defp start_httpd(_document_root, port, max_port) when port > max_port do
    tried = Enum.to_list((max_port - @max_port_offset)..max_port)
    {:error, {:no_available_port, tried}}
  end

  defp start_httpd(document_root, port, max_port) do
    opts = [
      port: port,
      server_root: to_charlist(document_root),
      document_root: to_charlist(document_root),
      server_name: ~c"localhost",
      directory_index: [~c"index.html"]
    ]

    case :inets.start(:httpd, opts) do
      {:ok, pid} ->
        {:ok, pid, port}

      {:error, {:already_started, pid}} ->
        {:ok, pid, port}

      {:error, reason} ->
        if eaddrinuse?(reason) do
          start_httpd(document_root, port + 1, max_port)
        else
          {:error, reason}
        end
    end
  end

  defp eaddrinuse?(reason), do: inspect(reason) =~ "eaddrinuse"
end
