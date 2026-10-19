using System;
using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;

namespace Utilvo.Pdf.Merger
{
    /// <summary>
    /// Structural inspection result for a PDF byte stream.
    /// </summary>
    public sealed class PdfInspectionResult
    {
        public bool IsValid { get; set; }
        public string Version { get; set; }
        public int PageCount { get; set; }
        public bool HasEof { get; set; }
        public int ByteLength { get; set; }
    }

    /// <summary>
    /// Lightweight utilities for inspecting PDF binary headers, counting pages, and merging PDF byte streams.
    /// </summary>
    public static class PdfMerger
    {
        private static readonly Regex PageRegex = new Regex(@"/Type\s*/Page\b(?!s)", RegexOptions.Compiled);
        private static readonly Regex VersionRegex = new Regex(@"%PDF-(\d+\.\d+)", RegexOptions.Compiled);
        private static readonly Regex StreamRegex = new Regex(@"stream\r?\n([\s\S]*?)\r?\nendstream", RegexOptions.Compiled);

        public static int CountPages(byte[] pdfBytes)
        {
            if (pdfBytes == null || pdfBytes.Length == 0) return 0;
            var raw = Encoding.GetEncoding("ISO-8859-1").GetString(pdfBytes);
            return PageRegex.Matches(raw).Count;
        }

        public static PdfInspectionResult Inspect(byte[] pdfBytes)
        {
            if (pdfBytes == null) throw new ArgumentNullException(nameof(pdfBytes));
            var raw = Encoding.GetEncoding("ISO-8859-1").GetString(pdfBytes);
            var header = raw.Length > 1024 ? raw.Substring(0, 1024) : raw;
            var verMatch = VersionRegex.Match(header);
            var hasEof = raw.Contains("%%EOF");
            return new PdfInspectionResult
            {
                IsValid = verMatch.Success && hasEof,
                Version = verMatch.Success ? verMatch.Groups[1].Value : null,
                PageCount = PageRegex.Matches(raw).Count,
                HasEof = hasEof,
                ByteLength = pdfBytes.Length
            };
        }

        public static byte[] Merge(IReadOnlyList<byte[]> documents)
        {
            if (documents == null || documents.Count == 0)
                throw new ArgumentException("At least one PDF document is required.", nameof(documents));

            var latin1 = Encoding.GetEncoding("ISO-8859-1");
            var streams = new List<string>();
            foreach (var doc in documents)
            {
                var raw = latin1.GetString(doc);
                var matches = StreamRegex.Matches(raw);
                if (matches.Count == 0)
                {
                    streams.Add("BT /F1 12 Tf 72 720 Td () Tj ET");
                }
                else
                {
                    foreach (Match m in matches)
                        streams.Add(m.Groups[1].Value);
                }
            }

            var objects = new List<string>
            {
                "<< /Type /Catalog /Pages 2 0 R >>",
                string.Empty,
                "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"
            };
            var kids = new List<string>();
            foreach (var s in streams)
            {
                objects.Add($"<< /Length {s.Length} >>\nstream\n{s}\nendstream");
                var contentId = objects.Count;
                objects.Add($"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 3 0 R >> >> /Contents {contentId} 0 R >>");
                var pageId = objects.Count;
                kids.Add($"{pageId} 0 R");
            }
            objects[1] = $"<< /Type /Pages /Kids [{string.Join(" ", kids)}] /Count {kids.Count} >>";

            var sb = new StringBuilder("%PDF-1.7\n");
            var offsets = new List<int> { 0 };
            for (var i = 0; i < objects.Count; i++)
            {
                offsets.Add(sb.Length);
                sb.Append($"{i + 1} 0 obj\n{objects[i]}\nendobj\n");
            }
            var xrefOffset = sb.Length;
            sb.Append($"xref\n0 {objects.Count + 1}\n0000000000 65535 f \n");
            for (var i = 1; i < offsets.Count; i++)
                sb.Append($"{offsets[i]:D10} 00000 n \n");
            sb.Append($"trailer\n<< /Size {objects.Count + 1} /Root 1 0 R >>\nstartxref\n{xrefOffset}\n%%EOF\n");
            return latin1.GetBytes(sb.ToString());
        }
    }
}
