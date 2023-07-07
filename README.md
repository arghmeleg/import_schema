# ImportSchema

`ImportSchema` provides a mix task that generates models from existing database schema.

    $ mix import_schema

This task has only been tested with Postgres and does not come with any guarantee of completeness or accuracy.

## Options
  * `-r`, `--repo` - the repo in your app to pull the schema from. If no repo is provided, the mix task will attempt to detect the repo and prompt the user to confirm or enter the correct repo name.

        $ mix import_schema -repo MyApp.Repo

  * `-sp`, `--strip-prefix` - a table prefix that will be stripped from module and file names.

    For example, if a table is named `webapp_users`, the repo is `MyApp.Repo`, and the desired module name is `MyApp.User` and the desired file name is `user.ex` instead of `MyApp.WebappUser` and `webapp_user.ex`:

        $ mix import_schema --strip-prefix webapp_

  * `-f`, `--force` - overwrite any existing models without prompting. The default without `--force` will prompt the user to see if they want to overwrite any models.

        $ mix import_schema --force

  * `-i`, `--ignore` - Table names to skip. `%` wildcards work as the query uses a `LIKE` statement.

    For example, if the `logs` table or any table starting with `temp` should not generate models:

        $ mix import_schema --ignore logs --ignore temp%

## Features

- The models are generated under the `lib/MY_APP/models/` directory

- Column data types are inferred from `information_schema`

- `belongs_to` associations are inferred from `information_schema`

## Installation

The package can be installed by adding `import_schema` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:import_schema, "~> 0.1.0"}
  ]
end
```
