defmodule DirLister do
  use GenServer

  def start_link(dir) do
    GenServer.start_link(__MODULE__, dir)
  end

  def init(dir) do
    IO.puts "DIR: #{dir} #{inspect(self)}"
    with {:ok, dir_contents} <- dir |> :file.list_dir,
        %{true: files, false: dirs} <- dir_contents
          |> Enum.map(&("#{dir}/#{&1}"))
          |> Enum.group_by(&File.regular?(&1))
          |> (&(Map.merge(%{true: [], false: []}, &1))).(),
        {:ok, _pid} <- Supervisor.start_link(Ultravisor, [items: files, worker_module: FileRenamer]),
        {:ok, _pid} <- Supervisor.start_link(Ultravisor, [items: dirs, worker_module: DirLister]) do
      {:ok, dir}
    else
      {:error, :enoent}  -> IO.puts("Can't find what your looking for 😞'")
      {:error, :enotdir} -> IO.puts("This is not a directory! 😡'")
    end
  end
end

defmodule FileRenamer do
  use GenServer

  def start_link(file) do
    GenServer.start_link(__MODULE__, file)
  end

  def init(file) do
    IO.puts "FILE: #{file}"
    {:ok, file}
  end
end

defmodule Ultravisor do
  use Supervisor

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg)
  end

  def init([items: items, worker_module: worker_module]) do
    items
      |> Enum.map(fn (item) ->
        worker(worker_module, [item], [id: "#{worker_module}_#{item}"])
      end)
      |> supervise(strategy: :one_for_one)
  end
end