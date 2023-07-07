defmodule ImportSchema.MixProject do
  use Mix.Project

  @source_url "https://github.com/arghmeleg/import_schema"
  @version "0.1.0"

  def project do
    [
      app: :import_schema,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.28.5", only: :dev, runtime: false},
      {:ecto, "~> 3.10"},
      {:ecto_sql, "~> 3.10"}
    ]
  end

  defp package do
    [
      description:
        "A mix task for bootstraping your Elixir project by generating modules from exisitng database schema.",
      files: ["lib", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["Steve DeGele"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      extras: [
        LICENSE: [title: "License"],
        "README.md": [title: "Overview"]
      ]
    ]
  end
end
