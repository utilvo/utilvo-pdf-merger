library utilvo_pdf_merger;

import 'dart:convert';
import 'dart:typed_data';

class PdfInspectionResult {
  final bool isValid;
  final String? version;
  final int pageCount;
  final bool hasEof;
  final int byteLength;

  const PdfInspectionResult({
    required this.isValid,
    required this.version,
    required this.pageCount,
    required this.hasEof,
    required this.byteLength,
  });
}

class UtilvoPdfMerger {
  static final RegExp _pageRegExp = RegExp(r'/Type\s*/Page\b(?!s)');
  static final RegExp _versionRegExp = RegExp(r'%PDF-(\d+\.\d+)');
  static final RegExp _streamRegExp =
      RegExp(r'stream\r?\n([\s\S]*?)\r?\nendstream');

  static int countPages(Uint8List pdfBytes) {
    final raw = latin1.decode(pdfBytes, allowInvalid: true);
    return _pageRegExp.allMatches(raw).length;
  }

  static PdfInspectionResult inspect(Uint8List pdfBytes) {
    final raw = latin1.decode(pdfBytes, allowInvalid: true);
    final header = raw.length > 1024 ? raw.substring(0, 1024) : raw;
    final verMatch = _versionRegExp.firstMatch(header);
    final hasEof = raw.contains('%%EOF');
    return PdfInspectionResult(
      isValid: verMatch != null && hasEof,
      version: verMatch?.group(1),
      pageCount: _pageRegExp.allMatches(raw).length,
      hasEof: hasEof,
      byteLength: pdfBytes.length,
    );
  }

  static Uint8List merge(List<Uint8List> documents) {
    if (documents.isEmpty) {
      throw ArgumentError('At least one PDF document is required');
    }
    final streams = <String>[];
    for (final doc in documents) {
      final raw = latin1.decode(doc, allowInvalid: true);
      final matches = _streamRegExp.allMatches(raw).toList();
      if (matches.isEmpty) {
        streams.add('BT /F1 12 Tf 72 720 Td () Tj ET');
      } else {
        for (final m in matches) {
          streams.add(m.group(1) ?? '');
        }
      }
    }

    final objects = <String>[
      '<< /Type /Catalog /Pages 2 0 R >>',
      '',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    ];
    final kids = <String>[];
    for (final s in streams) {
      objects.add('<< /Length ${s.length} >>\nstream\n$s\nendstream');
      final contentId = objects.length;
      objects.add(
          '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 3 0 R >> >> /Contents $contentId 0 R >>');
      final pageId = objects.length;
      kids.add('$pageId 0 R');
    }
    objects[1] =
        '<< /Type /Pages /Kids [${kids.join(' ')}] /Count ${kids.length} >>';

    final buffer = StringBuffer('%PDF-1.7\n');
    final offsets = <int>[0];
    for (var i = 0; i < objects.length; i++) {
      offsets.add(buffer.length);
      buffer.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
    }
    final xrefOffset = buffer.length;
    buffer.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
    for (var i = 1; i < offsets.length; i++) {
      buffer.write('${offsets[i].toString().padLeft(10, '0')} 00000 n \n');
    }
    buffer.write(
        'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xrefOffset\n%%EOF\n');
    return latin1.encode(buffer.toString());
  }
}
