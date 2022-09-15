defmodule DarthWeb.QueryParameters do
  import PhoenixSwagger.Path

  alias PhoenixSwagger.Path.PathObject

  def authorization(%PathObject{} = path, required \\ true) do
    path |> parameter("Authorization", :header, :string, "Bearer access token", required: required)
  end

  def list_query(%PathObject{} = path) do
    parameters path do
      sort_by(:query, :string, "The attribute to sort by.")
      sort_dir(:query, :string, "The sort direction.", enum: [:asc, :desc], default: :asc)
      all(:query, :boolean, "Disables paging, returns all results.", default: false)
      size(:query, :integer, "Number of elements per page.", minimum: 1, default: 12)
      page(:query, :integer, "Number of the page.", minimum: 1, default: 1)

      filters(
        :query,
        :string,
        ~s(A list of filters to reduce the results by, separated by <b>;</b> (semicolon\).<br>
           All filters are applied using <b>AND</b> semantics.<br>
           Each filter must use the format <b>TARGET_ATTRIBUTE,OPERATION,FILTER_VALUE</b> where the filter
           parts are separated by a <b>,</b> (comma\).
           <b>TARGET_ATTRIBUTE</b> depends on the model being filtered.<br>
           Standard operations are <b>&gt;</b>, <b>&gt;=</b>, <b>&lt;</b>, <b>&lt;=</b>, <b>==</b>, <b>!=</b>.
           Search operations are: <b>~</b> (direct match\), <b>~*</b> (sub-string search\),
           <b>=~</b> (prefix search\), <b>~=</b> (suffix search\).<br>
           The <b>FILTER_VALUE</b> for search operations can contain spaces, which are used as the delimiter for
           sub-strings, which are then used using <b>OR</b> semantics in the search itself.),
        default: ""
      )
    end
  end

  def asset_create_or_update(%PathObject{} = path, file_required \\ true) do
    parameters path do
      name(:formData, :string, "Name of the Asset", required: true)
      # FIXME: The type should be :file, but that doesn't seem to work.
      file(:formData, :object, "File data of the Asset as defined for HTTP uploads", required: file_required)
      attributes(:formData, :object, "Custom attributes of the Asset")
    end
  end

  def project_create_or_update(%PathObject{} = path) do
    parameters path do
      name(:formData, :string, "Name of the Asset")
      data(:formData, :object, "Custom project data")
      visibility(:formData, :string, "Current project visibility")
      primary_asset_id(:formData, :string, "ID for the asset lease to be used for previews")
    end
  end
end
