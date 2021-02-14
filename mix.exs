defmodule AuthorizeNet.Mixfile do
  use Mix.Project

  def project do
    [
      app: :elixir_authorizenet,
      name: "elixir_authorizenet",
      source_url: "https://github.com/marcelog/elixir_authorizenet",
      version: "0.4.1",
      elixir: "~> 1.10",
      description: description(),
      package: package(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    """
    Elixir client for the Authorize.Net merchant AIM API.

    A number of features are implemented, but I still consider this as WIP, and pull requests,
    suggestions, or other kind of feedback are very welcome!

    User guide at: https://github.com/marcelog/elixir_authorizenet.
    """
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Marcelo Gornstein"],
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => "https://github.com/marcelog/elixir_authorizenet"
      }
    ]
  end

  defp deps do
    [
      {:ibrowse, "~> 4.4"},
      {:ex_doc, "~> 0.23", only: :dev, runtime: false},
      {:sweet_xml, "~> 0.6"},
      {:xml_builder, "~> 2.1", override: true},
      {:servito, "~> 0.0.10", only: :test}
    ]
  end
end
