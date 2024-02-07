defmodule LibOss.MixProject do
  @moduledoc false
  use Mix.Project

  @name "lib_oss"
  @version "0.1.3"
  @repo_url "https://github.com/tt67wq/lib-oss"
  @description "A Elixir port SDK for Aliyun OSS"

  def project do
    [
      app: :lib_oss,
      version: @version,
      elixir: "~> 1.15",
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
      {:nimble_options, "~> 1.1"},
      {:mime, "~> 2.0"},
      {:jason, "~> 1.4"},
      {:elixir_xml_to_map, "~> 2.0"},
      {:finch, "~> 0.17"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:styler, "~> 0.11", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
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
