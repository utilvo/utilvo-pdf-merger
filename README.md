# utilvo-pdf-merger

Lightweight, zero-dependency library for inspecting PDF binary headers, counting `/Type /Page` objects, validating cross-reference (`xref`) tables, and merging multiple PDF byte streams into a single document with renumbered indirect objects.

## Installation

### Node.js (npm)
```bash
npm install utilvo-pdf-merger
```

### Python (PyPI)
```bash
pip install utilvo-pdf-merger
```

### Rust (Cargo)
```bash
cargo add utilvo-pdf-merger
```

### Go
```bash
go get github.com/utilvo/utilvo-pdf-merger
```

## Quick Start

### JavaScript / TypeScript
```js
import { inspectPdf, countPdfPages, mergePdfBuffers } from 'utilvo-pdf-merger';

const info = inspectPdf(pdfBytes);
console.log(info.version, info.pageCount, info.isValid);

const mergedBytes = mergePdfBuffers([pdfBufferA, pdfBufferB]);
```

### Python
```python
from utilvo_pdf_merger import inspect_pdf, count_pdf_pages, merge_pdf_bytes

info = inspect_pdf(pdf_bytes)
print(info["version"], info["page_count"], info["is_valid"])

merged = merge_pdf_bytes([pdf_a, pdf_b])
```

## API Reference

| Function | Parameters | Returns | Description |
| :--- | :--- | :--- | :--- |
| `inspectPdf` / `inspect_pdf` | `bytes: Uint8Array \| bytes` | `PdfInspectionResult` | Extracts PDF specification version (`1.4`–`2.0`), page count, `startxref` offset, and `%%EOF` integrity status. |
| `countPdfPages` / `count_pdf_pages` | `bytes: Uint8Array \| bytes` | `number` | Counts leaf `/Type /Page` dictionary entries (excluding `/Type /Pages` parent nodes). |
| `mergePdfBuffers` / `merge_pdf_bytes` | `documents: Array<Uint8Array \| bytes>` | `Uint8Array \| bytes` | Extracts page content streams and constructs a consolidated PDF document with a unified `/Pages` root and rebuilt `xref` table. |

## License

MIT
