defmodule Mix.Tasks.ImportSchema do
  @moduledoc """
  Generates models from database schema
  """
  use Mix.Task

  @file_dir "lib/*/models/"

  @doc """
  `mix import_schema`
  """

  @arg_opts [aliases: [r: :repo], switches: [repo: :string]]

  @start_apps [:ecto, :ecto_sql]

  @type_map %{
    "datetime" => :utc_datetime,
    "date" => :date,
    "varchar" => :string,
    "float" => :float,
    "int" => :integer,
    "tinyint" => :integer,
    "mediumtext" => :string,
    "longtext" => :string,
    "text" => :string,
    "json" => :map
  }

  def run(args_string) do
    args = parse_args(args_string)
    # table = List.first(args)
    # repo = List.first(args)
    IO.inspect(args)
    IO.inspect(args.repo)
    repo = String.to_existing_atom(args.repo) |> IO.inspect()
    # Enum.each(@start_apps, &Application.ensure_all_started/1)
    # repo_pid = repo.connect()
    #
    # Application.ensure_started(repo_pid, [])
    #
    # {:ok, %{rows: rows}} = repo.query("
    #   SELECT column_name, data_type
    #   FROM information_schema.columns
    #   WHERE table_name = '#{table}' ORDER BY column_name
    # ")
    #
    # fields =
    #   rows
    #   |> Enum.reject(fn [name, _type] -> name == "id" end)
    #   |> Enum.map(fn [name, type] -> {name, @type_map[type]} end)
    #
    # filename = file_path(@file_dir, "#{String.trim(table, "s")}.ex")
    #
    # safe_write(filename, template(table, fields))
  end

  defp safe_write(filename, content) do
    if !File.exists?(filename) ||
         IO.gets(
           "#{IO.ANSI.green()}#{filename}#{IO.ANSI.reset()} aready exists. Overwrite? [y/N] "
         ) == "y\n" do
      File.write(filename, content)
      IO.puts("Created #{IO.ANSI.blue()}#{filename}#{IO.ANSI.reset()}")
    end
  end

  defp file_path(dir, filename) do
    Path.join([File.cwd!(), dir, filename])
  end

  defp template(name, fields) do
    module_name = name |> Macro.camelize() |> String.trim("s")

    template_fields =
      Enum.map_join(fields, "\n", fn {name, type} -> "    field :#{name}, :#{type}" end)

    ~s/defmodule #{repo}.#{module_name} do
  @moduledoc """
  Ecto model representing `#{name}` schema.
  """
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "#{name}" do
#{template_fields}
  end
end
/
  end

  defp parse_args(args) do
    args
    |> OptionParser.parse(@arg_opts)
    |> Tuple.to_list()
    |> List.first()
    |> Enum.into(%{})
  end
end
