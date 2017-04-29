defmodule Romina do
  def ls_map(path \\ ".", fun \\ &Path.join(&1, &2)) do
    cond do
      File.regular?(path) -> [path]
      File.dir?(path)     ->
        path
          |> p_ls!
          |> Flow.flat_map(fn el -> el |> (&fun.(path, &1)).() |> ls_map end)
          |> Flow.partition
          |> Flow.reduce(fn -> [] end, fn el, acc -> [el|acc] end)
          |> Flow.departition(fn -> [] end, fn el, acc -> [el|acc] end, &(&1))
          |> Enum.to_list
      true -> []
    end
  end

  defp p_ls!(path) do
    path
      |> IO.chardata_to_string
      |> :file.list_dir
      |> (&p_chardata_to_string(&1)).()
  end

  defp p_chardata_to_string({:error, error}), do: error
  defp p_chardata_to_string({:ok, enum}) do
    enum
      |> Flow.from_enumerable
      |> Flow.map(&IO.chardata_to_string/1)
  end
end
