# utilvo-pdf-merger

Lightweight, zero-dependency library for inspecting PDF binary headers (`%PDF-1.x`), counting `/Type /Page` objects, validating cross-reference (`xref`) tables, and merging multiple PDF byte streams into a single document with renumbered indirect objects.

Built as the open-source companion library for the **[Merge PDF](https://utilvo.com/pdf-tools/merge-pdf)** document processing utility, `utilvo-pdf-merger` allows developers to pre-validate PDF buffers, verify `%%EOF` markers, count total pages across multi-file batches, and concatenate uncompressed PDF streams programmatically in Node.js, Python, Go, Rust, PHP, Ruby, Elixir, Dart, Swift, Lua, and .NET.

## Architecture & How It Works

When combining multiple PDF files into a single document, raw byte concatenation is invalid because each PDF file contains its own independent object numbering (`1 0 obj`, `2 0 obj`, ...) and a byte-offset cross-reference (`xref`) table at the end of the file:

1. **Header & Integrity Inspection (`inspectPdf` / `inspect_pdf`):** Reads the first 1,024 bytes of each buffer to verify the `%PDF-1.x` specification header and scans the trailer for a valid `%%EOF` marker.
2. **Page Tree Counting (`countPdfPages` / `count_pdf_pages`):** Scans indirect dictionary objects matching `/Type /Page\b(?!s)` to count leaf page nodes while excluding parent `/Type /Pages` catalog containers.
3. **Indirect Object Renumbering & `xref` Reconstruction (`mergePdfBuffers` / `merge_pdf_bytes`):** Extracts page content streams across all input documents, assigns sequential object IDs under a unified `/Type /Pages` root array (`/Kids [...]`), and calculates exact byte offsets (`%010d 00000 n `) to emit a standards-compliant `xref` table and `trailer` dictionary.

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

### Dart / Flutter
```bash
dart pub add utilvo_pdf_merger
```

### Elixir (Hex)
```elixir
{:utilvo_pdf_merger, "~> 1.0"}
```

### Ruby (RubyGems)
```bash
gem install utilvo-pdf-merger
```

## Usage Examples

### JavaScript / TypeScript
```js
import { inspectPdf, countPdfPages, mergePdfBuffers } from 'utilvo-pdf-merger';

// 1. Inspect an individual PDF buffer before merging
const info = inspectPdf(pdfBytes);
console.log(info.version, info.pageCount, info.isValid);

// 2. Merge multiple PDF byte buffers into a single PDF document
const mergedBytes = mergePdfBuffers([pdfBufferA, pdfBufferB]);
```

### Python
```python
from utilvo_pdf_merger import inspect_pdf, count_pdf_pages, merge_pdf_bytes

# 1. Validate PDF header, EOF marker, and page count
info = inspect_pdf(pdf_bytes)
print(info["version"], info["page_count"], info["is_valid"])

# 2. Merge multiple PDF byte streams into a unified PDF
merged = merge_pdf_bytes([pdf_a, pdf_b])
```

### Rust
```rust
use utilvo_pdf_merger::{inspect_pdf, count_pdf_pages, merge_pdf_buffers};

let info = inspect_pdf(&pdf_bytes);
assert!(info.is_valid);

let merged = merge_pdf_buffers(&[&pdf_a, &pdf_b]);
```

### Go
```go
import utilvopdfmerger "github.com/utilvo/utilvo-pdf-merger"

info := utilvopdfmerger.InspectPdf(pdfBytes)
merged, err := utilvopdfmerger.MergePdfBuffers([][]byte{pdfA, pdfB})
```

## API Reference

| Function | Parameters | Returns | Description |
| :--- | :--- | :--- | :--- |
| `inspectPdf` / `inspect_pdf` | `bytes: Uint8Array \| bytes` | `PdfInspectionResult` | Extracts PDF specification version (`1.4`–`2.0`), page count, and `%%EOF` integrity status. |
| `countPdfPages` / `count_pdf_pages` | `bytes: Uint8Array \| bytes` | `number` | Counts leaf `/Type /Page` dictionary entries (excluding `/Type /Pages` parent nodes). |
| `mergePdfBuffers` / `merge_pdf_bytes` | `documents: Array<Uint8Array \| bytes>` | `Uint8Array \| bytes` | Extracts page content streams and constructs a consolidated PDF document with a unified `/Pages` root and rebuilt `xref` table. |

## License

MIT
