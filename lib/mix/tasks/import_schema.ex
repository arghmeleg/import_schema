defmodule Mix.Tasks.ImportSchema do
  @moduledoc """
  Generates models from database schema
  """
  use Mix.Task

  @doc """
  `mix import_schema`
  """

  @arg_opts [aliases: [r: :repo], switches: [repo: :string, strip_prefix: :string]]

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
    "json" => :map,
    "boolean" => :boolean,
    "bigint" => :integer,
    "integer" => :integer,
    "character varying" => :string,
    "jsonb" => :map
  }
  @requirements ["app.config"]
  def run(args_string) do
    # Mix.Task.run("app.start")

    args = parse_args(args_string)
    # table = List.first(args)
    # repo = List.first(args)
    IO.inspect(args)
    # Application.loaded_applications() |> IO.inspect()
    # File.cwd!() |> IO.jinspect()
    repo = get_repo(args)
    # IO.inspect(get_repo(args))
    # Enum.each(@start_apps, &Application.ensure_all_started/1) |> IO.inspect
    # repo_pid = repo.connect()
    # Application.ensure_started(repo_pid, [])
    # Mix.Ecto.ensure_started(repo, [])
    # WHERE table_name = '#{table}'

    Mix.Ecto.ensure_repo(repo, []) |> IO.inspect()

    # config = repo.config()
    # mode = Keyword.get([], :mode, :permanent)
    # apps = [:ecto_sql | config[:start_apps_before_migration] || []]
    #
    # extra_started =
    #   Enum.flat_map(apps, fn app ->
    #     {:ok, started} = Application.ensure_all_started(app, mode)
    #     started
    #   end)
    #
    # {:ok, repo_started} = repo.__adapter__().ensure_all_started(config, mode) |> IO.inspect()

    # Mix.Ecto.parse_repo([""])

    # {:ok, pid} = repo.start_link(pool_size: 1) |> IO.inspect()

    IO.inspect(Stix.Repo.config())

    repo
    |> query("
        SELECT table_name, column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = 'public'
        ORDER BY
        table_name, column_name
        ")
    |> Enum.reject(&(&1.column_name == "id"))
    |> Enum.map(&Map.put(&1, :type, @type_map[&1.data_type]))
    |> Enum.group_by(& &1.table_name)
    |> Enum.each(&build_model(&1, args))
  end

  defp build_model({table, columns}, _args) do
    filename = file_path("lib/#{app_dir()}/models/", "#{String.trim(table, "s")}.ex")
    IO.puts(filename)
    safe_write(filename, template(table, columns, Macro.camelize(app_dir())))
  end

  defp query(repo, q) do
    {:ok, {:ok, %{rows: rows, columns: cols}}, _apps} =
      Ecto.Migrator.with_repo(repo, fn r ->
        r.query(q)
      end)

    atom_cols = Enum.map(cols, &String.to_atom/1)
    Enum.map(rows, fn r -> Enum.into(Enum.zip(atom_cols, r), %{}) end)
  end

  defp get_repo(%{repo: repo}) do
    :FIXME_HANDLE_ERROR
    String.to_existing_atom(repo)
  end

  defp app_dir do
    Path.basename(File.cwd!())
  end

  defp get_repo(args) do
    string_app = Macro.camelize(app_dir())

    try do
      repo_guess = String.to_existing_atom("Elixir." <> string_app <> ".Repo")
      expected_repo_guess = String.replace_prefix("#{repo_guess}", "Elixir.", "")

      IO.puts("No repo given, guessing #{green(expected_repo_guess)}?")

      resp =
        "Press enter to continue or enter correct MyApp.Repo to continue: "
        |> IO.gets()
        |> String.trim()

      if resp == "" do
        repo_guess
      else
        args |> Map.put(:repo, resp) |> get_repo()
      end
    rescue
      RuntimeError -> :FIXME
    end
  end

  defp green(text) do
    ansi_color(:green, text)
  end

  defp blue(text) do
    ansi_color(:blue, text)
  end

  defp ansi_color(color, text) do
    "#{apply(IO.ANSI, color, [])}#{text}#{IO.ANSI.reset()}"
  end

  defp safe_write(filename, content) do
    if !File.exists?(filename) ||
         IO.gets("#{green(filename)} aready exists. Overwrite? [y/N] ") == "y\n" do
      File.write(filename, content)
      IO.puts("Created #{blue(filename)}")
    end
  end

  defp file_path(dir, filename) do
    Path.join([File.cwd!(), dir, filename])
  end

  defp template(name, fields, repo) do
    IO.inspect(fields)
    module_name = name |> Macro.camelize() |> String.trim("s")

    template_fields =
      Enum.map_join(fields, "\n", fn f -> "    field :#{f.column_name}, :#{f.type}" end)

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
