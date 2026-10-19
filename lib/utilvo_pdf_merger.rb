# frozen_string_literal: true

module UtilvoPdfMerger
  VERSION = "1.0.0"

  def self.count_pages(pdf_bytes)
    pdf_bytes.to_s.scan(%r{/Type\s*/Page\b(?!s)}).length
  end

  def self.inspect_pdf(pdf_bytes)
    raw = pdf_bytes.to_s
    ver_match = raw[0, 1024].match(/%PDF-(\d+\.\d+)/)
    has_eof = raw.include?("%%EOF")
    {
      is_valid: !ver_match.nil? && has_eof,
      version: ver_match ? ver_match[1] : nil,
      page_count: count_pages(raw),
      has_eof: has_eof,
      byte_length: raw.bytesize
    }
  end

  def self.merge(documents)
    raise ArgumentError, "At least one PDF document is required" if documents.nil? || documents.empty?

    streams = []
    documents.each do |doc|
      found = doc.to_s.scan(/stream\r?\n([\s\S]*?)\r?\nendstream/).flatten
      if found.empty?
        streams << "BT /F1 12 Tf 72 720 Td () Tj ET"
      else
        streams.concat(found)
      end
    end

    objects = [
      "<< /Type /Catalog /Pages 2 0 R >>",
      "",
      "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"
    ]
    kids = []
    streams.each do |s|
      objects << "<< /Length #{s.bytesize} >>\nstream\n#{s}\nendstream"
      content_id = objects.length
      objects << "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 3 0 R >> >> /Contents #{content_id} 0 R >>"
      page_id = objects.length
      kids << "#{page_id} 0 R"
    end
    objects[1] = "<< /Type /Pages /Kids [#{kids.join(' ')}] /Count #{kids.length} >>"

    out = +"%PDF-1.7\n"
    offsets = [0]
    objects.each_with_index do |body, idx|
      offsets << out.bytesize
      out << "#{idx + 1} 0 obj\n#{body}\nendobj\n"
    end
    xref_offset = out.bytesize
    out << "xref\n0 #{objects.length + 1}\n0000000000 65535 f \n"
    offsets[1..].each do |off|
      out << format("%010d 00000 n \n", off)
    end
    out << "trailer\n<< /Size #{objects.length + 1} /Root 1 0 R >>\nstartxref\n#{xref_offset}\n%%EOF\n"
    out
  end
end
