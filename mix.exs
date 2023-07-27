defmodule LibOss.MixProject do
  use Mix.Project

  @name "lib_oss"
  @version "0.1.0"
  @repo_url "https://github.com/tt67wq/lib-oss"
  @description "A Elixir port SDK for Aliyun OSS"

  def project do
    [
      app: :lib_oss,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      source_url: @repo_url,
      name: @name,
      package: package(),
      description: @description
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_options, "~> 0.5"},
      {:mime, "~> 2.0"},
      {:jason, "~> 1.4"},
      {:elixir_xml_to_map, "~> 2.0"},
      {:finch, "~> 0.16"},
      {:dialyxir, "~> 1.3", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @repo_url
      }
    ]
  end
end
