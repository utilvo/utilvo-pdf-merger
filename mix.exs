defmodule UtilvoPdfMerger.MixProject do
  use Mix.Project

  def project do
    [
      app: :utilvo_pdf_merger,
      version: "1.0.0",
      elixir: "~> 1.12",
      description: "Lightweight Elixir library for inspecting PDF binary headers, counting pages, and merging PDF byte streams.",
      package: package(),
      deps: []
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "Homepage" => "https://utilvo.com/pdf-tools/merge-pdf",
        "GitHub" => "https://github.com/utilvo/utilvo-pdf-merger"
      }
    ]
  end
end
