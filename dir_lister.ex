defmodule DirLister do
  use GenServer

  def start_link(item), do: GenServer.start_link(__MODULE__, item)
  def run(pid), do: GenServer.cast(pid, :run)

  def init(item), do: {:ok, item}

  def handle_cast(:run, item) do
    IO.puts "DIR: #{item}"
    with {:ok, dir_contents}        <- item |> :file.list_dir,
        %{true: files, false: dirs} <- dir_contents
          |> Enum.map(&("#{item}/#{&1}"))
          |> Enum.group_by(&File.regular?(&1))
          |> (&(Map.merge(%{true: [], false: []}, &1))).(),
        %{ok: pids, error: []} <- Ultravisor.start_link(items: files, worker_module: FileRenamer),
        %{ok: pids, error: []} <- Ultravisor.start_link(items: dirs, worker_module: DirLister) do
      {:noreply, :item}
    else
      {:error, :enoent}  -> IO.puts("Can't find what your looking for 😞'")
      {:error, :enotdir} -> IO.puts("This is not a directory! 😡'")
    end
  end

  def terminate(:normal, item), do: IO.puts "DIR: done with #{item}!"
end

defmodule FileRenamer do
  use GenServer

  def start_link(item), do: GenServer.start_link(__MODULE__, item)
  def run(pid), do: GenServer.cast(pid, :run)

  def init(item), do: {:ok, item}

  def handle_cast(:run, item) do
    IO.puts "FILE: #{item}"
    {:stop, :normal, item}
  end

  def terminate(:normal, item), do: IO.puts "FILE: done with #{item}!"
end

defmodule Ultravisor do
  use Supervisor

  def start_link(items: items, worker_module: worker_module) do
    IO.puts "Ultravisor #{worker_module} started"
    {:ok, pid} = Supervisor.start_link(__MODULE__, worker_module)
    items |> Enum.reduce(%{ok: [], error: []}, fn(item, acc) ->
      {result_atom, pid} = Supervisor.start_child(pid, [item])
      worker_module.run(pid)
      {_, acc} = Map.get_and_update(acc, result_atom, &{&1, [pid|&1]})
      acc
    end)
  end

  def init(worker_module) do
    supervise([worker(worker_module, [], restart: :transient)], strategy: :simple_one_for_one)
  end
end