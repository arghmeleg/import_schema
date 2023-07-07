defmodule Mix.Tasks.ImportSchema do
  @moduledoc """
  Generates models from database schema
  """
  use Mix.Task

  @doc """
  `mix import_schema`
  """

  @arg_opts [
    aliases: [r: :repo, sp: :strip_prefix, f: :force, i: :ignore],
    switches: [repo: :string, strip_prefix: :string, force: :boolean, ignore: :keep]
  ]

  @start_apps [:ecto, :ecto_sql]

  @type_map %{
    "bytea" => :binary,
    "date" => :date,
    "datetime" => :utc_datetime,
    "bigint" => :integer,
    "boolean" => :boolean,
    "character varying" => :string,
    "float" => :float,
    "int" => :integer,
    "integer" => :integer,
    "json" => :map,
    "jsonb" => :map,
    "longtext" => :string,
    "mediumtext" => :string,
    "text" => :string,
    "tinyint" => :integer,
    "timestamp with time zone" => :utc_datetime_usec,
    "timestamp without time zone" => :utc_datetime,
    "varchar" => :string
  }

  @requirements ["app.config"]

  def run(args_input) do
    repo = get_repo(args_input)

    args =
      args_input
      |> OptionParser.parse(@arg_opts)
      |> Tuple.to_list()
      |> List.first()
      |> Keyword.put(:repo, repo)

    ignores =
      Enum.map_join(Keyword.get_values(args, :ignore), " ", fn ignore ->
        "AND c.table_name NOT LIKE '#{ignore}'"
      end)

    repo
    |> query("
        WITH fks AS (
          SELECT
            tc.table_name,
            kcu.column_name,
            ccu.table_name AS foreign_table_name,
            ccu.column_name AS foreign_column_name
          FROM
            information_schema.table_constraints AS tc
            JOIN information_schema.key_column_usage AS kcu
              ON tc.constraint_name = kcu.constraint_name
              AND tc.table_schema = kcu.table_schema
            JOIN information_schema.constraint_column_usage AS ccu
              ON ccu.constraint_name = tc.constraint_name
              AND ccu.table_schema = tc.table_schema
          WHERE tc.constraint_type = 'FOREIGN KEY'
        )
        SELECT c.table_name, c.column_name, c.data_type, fks.foreign_table_name, fks.foreign_column_name
        FROM information_schema.columns c
        LEFT OUTER JOIN fks ON fks.table_name = c.table_name AND fks.column_name = c.column_name
        WHERE c.table_schema = 'public'
        #{ignores}
        ORDER BY
        c.table_name, fks.foreign_table_name IS NULL DESC, fks.foreign_table_name, fks.foreign_column_name, c.column_name
        ")
    |> Enum.reject(&(&1.column_name == "id"))
    |> Enum.map(&Map.put(&1, :type, @type_map[&1.data_type]))
    |> Enum.group_by(& &1.table_name)
    |> Enum.each(&build_model(&1, args))
  end

  defp build_model({table, columns}, args) do
    module_name = get_module_name(table, args)

    filename =
      file_path(
        "lib/#{app_dir()}/models/",
        "#{String.trim_trailing(strip_prefix(table, args), "s")}.ex"
      )

    safe_write(filename, template(table, columns, module_name, args), args)
  end

  defp get_module_name(table, args) do
    module_basename =
      table
      |> strip_prefix(args)
      |> Macro.camelize()
      |> String.trim("s")

    String.replace_suffix(chomp_elixir(args[:repo]), ".Repo", "") <> "." <> module_basename
  end

  defp strip_prefix(table, args) do
    if args[:strip_prefix] do
      String.replace_prefix(table, args[:strip_prefix], "")
    else
      table
    end
  end

  defp query(repo, q) do
    {:ok, {:ok, %{rows: rows, columns: cols}}, _apps} =
      Ecto.Migrator.with_repo(repo, fn r ->
        r.query(q)
      end)

    atom_cols = Enum.map(cols, &String.to_atom/1)
    Enum.map(rows, fn r -> Enum.into(Enum.zip(atom_cols, r), %{}) end)
  end

  defp app_dir do
    Path.basename(File.cwd!())
  end

  defp get_repo(args_string) do
    potential_repos =
      args_string
      |> Mix.Ecto.parse_repo()
      |> Enum.map(fn maybe_repo ->
        try do
          Mix.Ecto.ensure_repo(maybe_repo, [])
        rescue
          _ -> nil
        end
      end)
      |> Enum.filter(& &1)

    repo_guess = List.first(potential_repos)

    resp =
      if repo_guess do
        IO.puts("Guessing #{green(chomp_elixir(repo_guess))}?")

        "Enter a different MyApp.Repo or press [enter] to continue: "
      else
        "Please enter a valid MyApp.Repo to continue: "
      end
      |> IO.gets()
      |> String.trim()

    if resp == "" && repo_guess do
      repo_guess
    else
      get_repo(["-r", resp])
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

  defp safe_write(filename, content, args) do
    if !File.exists?(filename) || args[:force] ||
         IO.gets("#{green(filename)} aready exists. Overwrite? [y/N] ") == "y\n" do
      File.write(filename, content)
      IO.puts("Wrote to #{blue(filename)}")
    end
  end

  defp file_path(dir, filename) do
    Path.join([File.cwd!(), dir, filename])
  end

  defp template(table, fields, module_name, args) do
    template_fields =
      Enum.map_join(fields, "\n", fn f -> "    #{field(f, args)}" end)

    ~s/defmodule #{module_name} do
  @moduledoc """
  Ecto model representing `#{table}` schema.
  """
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "#{table}" do
#{template_fields}
  end
end
/
  end

  defp field(%{foreign_table_name: ft, foreign_column_name: "id"}, args) do
    "belongs_to :#{strip_prefix(ft, args)}, #{get_module_name(ft, args)}"
  end

  defp field(f, _args) do
    "field :#{f.column_name}, :#{f.type}"
  end

  defp chomp_elixir(string) do
    String.replace_prefix("#{string}", "Elixir.", "")
  end
end
