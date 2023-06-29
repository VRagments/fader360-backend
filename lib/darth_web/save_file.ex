defmodule DarthWeb.SaveFile do
  def save_file(file, response) do
    save_file = fn response, file, download_file ->
      response_id = response.id

      receive do
        %HTTPoison.AsyncStatus{code: _status_code, id: ^response_id} ->
          HTTPoison.stream_next(response)
          download_file.(response, file, download_file)

        %HTTPoison.AsyncHeaders{headers: _headers, id: ^response_id} ->
          HTTPoison.stream_next(response)
          download_file.(response, file, download_file)

        %HTTPoison.AsyncChunk{chunk: chunk, id: ^response_id} ->
          IO.binwrite(file, chunk)
          HTTPoison.stream_next(response)
          download_file.(response, file, download_file)

        %HTTPoison.AsyncEnd{id: ^response_id} ->
          File.close(file)
      end
    end

    save_file.(response, file, save_file)
  end

  def write_to_file(file_path, content) do
    case File.write(file_path, content) do
      :ok -> :ok
      {:error, reason} -> {:error, "unable to write into project result text file #{inspect(reason)}"}
    end
  end
end
