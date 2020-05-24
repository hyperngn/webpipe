defmodule Webpipe.Templates do
  require EEx
  @templates :code.priv_dir(:webpipe) |> Path.join("templates/*.html.eex") |> Path.wildcard()

  for template <- @templates do
    fn_name = template |> Path.basename() |> String.to_atom()
    EEx.function_from_file(:def, fn_name, template, [:assigns])
  end
end
