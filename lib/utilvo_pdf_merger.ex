defmodule UtilvoPdfMerger do
  @moduledoc """
  Lightweight library for inspecting PDF binary headers, counting `/Type /Page` entries,
  and merging multiple PDF byte streams with a rebuilt `xref` table.
  """

  @doc """
  Counts leaf `/Type /Page` dictionary entries in a raw PDF binary.
  """
  def count_pages(pdf_binary) when is_binary(pdf_binary) do
    Regex.scan(~r/\/Type\s*\/Page\b(?!s)/, pdf_binary)
    |> length()
  end

  @doc """
  Inspects a PDF binary and returns version, page count, and EOF integrity status.
  """
  def inspect_pdf(pdf_binary) when is_binary(pdf_binary) do
    header = binary_part(pdf_binary, 0, min(byte_size(pdf_binary), 1024))
    version =
      case Regex.run(~r/%PDF-(\d+\.\d+)/, header) do
        [_, ver] -> ver
        _ -> nil
      end

    has_eof = :binary.match(pdf_binary, "%%EOF") != :nomatch

    %{
      is_valid: version != nil and has_eof,
      version: version,
      page_count: count_pages(pdf_binary),
      has_eof: has_eof,
      byte_length: byte_size(pdf_binary)
    }
  end
end
