defmodule Grimoire.DevServerTest do
  use ExUnit.Case, async: false

  alias Grimoire.DevServer

  setup do
    :inets.start()

    dir =
      Path.join(System.tmp_dir!(), "grimoire_dev_server_test_#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    File.write!(Path.join(dir, "index.html"), "<h1>Fixture Home</h1>")
    on_exit(fn -> File.rm_rf!(dir) end)
    %{document_root: dir}
  end

  defp unique_name, do: :"dev_server_test_#{System.unique_integer([:positive])}"
  defp unique_port, do: 20_000 + :rand.uniform(9_000)

  describe "start/1, port/1, stop/1" do
    test "GET / returns the fixture _site/index.html content", %{document_root: dir} do
      name = unique_name()
      port = unique_port()

      assert {:ok, _pid} = DevServer.start(document_root: dir, port: port, name: name)
      on_exit(fn -> DevServer.stop(name) end)

      assert DevServer.port(name) == port

      assert {:ok, {{_, 200, _}, _headers, body}} =
               :httpc.request(:get, {~c"http://localhost:#{port}/", []}, [], [])

      assert to_string(body) =~ "Fixture Home"
    end

    test "falls back to the next port when the requested one is already bound", %{
      document_root: dir
    } do
      port = unique_port()
      {:ok, occupying_socket} = :gen_tcp.listen(port, [])

      name = unique_name()
      assert {:ok, _pid} = DevServer.start(document_root: dir, port: port, name: name)
      on_exit(fn -> DevServer.stop(name) end)

      assert DevServer.port(name) == port + 1

      :gen_tcp.close(occupying_socket)
    end

    test "stop/1 stops the underlying httpd cleanly, no lingering listener", %{document_root: dir} do
      name = unique_name()
      port = unique_port()

      {:ok, pid} = DevServer.start(document_root: dir, port: port, name: name)
      assert :ok = DevServer.stop(name)

      refute Process.alive?(pid)
      refute Process.whereis(name)
      refute DevServer.port(name)
    end

    test "starting twice under the same name is idempotent (already-started handled gracefully)", %{
      document_root: dir
    } do
      name = unique_name()
      port = unique_port()

      assert {:ok, pid} = DevServer.start(document_root: dir, port: port, name: name)
      assert {:ok, ^pid} = DevServer.start(document_root: dir, port: port, name: name)

      DevServer.stop(name)
    end
  end

  describe "supervision" do
    test "child_spec declares restart: :transient" do
      assert DevServer.child_spec([]).restart == :transient
    end

    test "Grimoire.ServeSupervisor is registered under Grimoire.Application's supervisor" do
      children = Supervisor.which_children(Grimoire.Supervisor)
      assert Enum.any?(children, fn {id, _pid, _type, _mods} -> id == Grimoire.ServeSupervisor end)
    end
  end
end
