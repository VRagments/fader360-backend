defmodule DarthWeb.Components.UploadProgress do
  use DarthWeb, :component

  attr :uploads, :any, required: true

  def render(assigns) do
    ~H"""
      <div class="flex flex-col mt-4 px-4 py-2 max-w-xl mx-auto" phx-drop-target={@uploads.media.ref}>
        <%= for entry <- @uploads.media.entries do %>
          <article class="upload-entry">
              <progress value={entry.progress} max="100"> <%= entry.progress %>%
              </progress>
              <button type="button" phx-click="cancel-upload" phx-value-ref={entry.ref}
                  aria-label="cancel">&times;</button>
              <%= for err <- upload_errors(@uploads.media, entry) do %>
                  <p class="alert alert-danger"><%= error_to_string(err) %></p>
              <% end %>
          </article>
      <% end %>
      <%= for err <- upload_errors(@uploads.media) do %>
          <p class="alert alert-danger"><%= error_to_string(err) %></p>
      <% end %>
    </div>
    """
  end

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
end
