/**
 * Metadata and structural validation results returned by {@link inspectPdf}.
 */
export interface PdfInspectionResult {
  /** Whether the document contains both a valid `%PDF-1.x` header and `%%EOF` trailer marker. */
  isValid: boolean;
  /** Extracted PDF specification version (for example `"1.7"`), or `null` if missing. */
  version: string | null;
  /** Total number of `/Type /Page` leaf objects detected in the document buffer. */
  pageCount: number;
  /** Whether the byte stream contains a closing `%%EOF` marker. */
  hasEof: boolean;
  /** Total byte length of the inspected PDF buffer. */
  byteLength: number;
}

const PAGE_REGEX = /\/Type\s*\/Page\b(?!s)/g;
const VERSION_REGEX = /%PDF-(\d+\.\d+)/;
const STREAM_REGEX = /stream\r?\n([\s\S]*?)\r?\nendstream/g;

function toLatin1(input: Uint8Array | string): string {
  if (typeof input === "string") return input;
  let out = "";
  for (let i = 0; i < input.length; i++) {
    out += String.fromCharCode(input[i]);
  }
  return out;
}

function fromLatin1(str: string): Uint8Array {
  const out = new Uint8Array(str.length);
  for (let i = 0; i < str.length; i++) {
    out[i] = str.charCodeAt(i) & 0xff;
  }
  return out;
}

/**
 * Counts the number of `/Type /Page` dictionary entries in a raw PDF byte buffer or Latin-1 string.
 *
 * @param pdfData Raw PDF bytes (`Uint8Array`) or binary string.
 * @returns Total number of pages found in the PDF stream.
 */
export function countPdfPages(pdfData: Uint8Array | string): number {
  const raw = toLatin1(pdfData);
  const matches = raw.match(PAGE_REGEX);
  return matches ? matches.length : 0;
}

/**
 * Inspects a PDF buffer to verify its `%PDF-1.x` header, `%%EOF` marker, version, and page count.
 *
 * @param pdfData Raw PDF bytes (`Uint8Array`) or binary string.
 * @returns A {@link PdfInspectionResult} summary of the PDF structure.
 */
export function inspectPdf(pdfData: Uint8Array | string): PdfInspectionResult {
  const raw = toLatin1(pdfData);
  const verMatch = raw.slice(0, 1024).match(VERSION_REGEX);
  const hasEof = raw.includes("%%EOF");
  const pageCount = countPdfPages(raw);
  return {
    isValid: Boolean(verMatch && hasEof),
    version: verMatch ? verMatch[1] : null,
    pageCount,
    hasEof,
    byteLength: raw.length,
  };
}

/**
 * Merges multiple uncompressed PDF buffers into a single valid `%PDF-1.7` document with renumbered objects and rebuilt `xref` table.
 *
 * @param documents Array of PDF byte buffers (`Uint8Array`) or binary strings to merge in order.
 * @returns A `Uint8Array` containing the merged PDF document.
 */
export function mergePdfBuffers(documents: Array<Uint8Array | string>): Uint8Array {
  if (!Array.isArray(documents) || documents.length === 0) {
    throw new Error("At least one PDF document is required");
  }
  const pageStreams: string[] = [];
  for (const doc of documents) {
    const raw = toLatin1(doc);
    let m: RegExpExecArray | null;
    STREAM_REGEX.lastIndex = 0;
    let found = 0;
    while ((m = STREAM_REGEX.exec(raw)) !== null) {
      pageStreams.push(m[1]);
      found++;
    }
    if (found === 0) {
      pageStreams.push("BT /F1 12 Tf 72 720 Td () Tj ET");
    }
  }

  const objects: string[] = [];
  const addObj = (body: string): number => {
    objects.push(body);
    return objects.length;
  };

  addObj("<< /Type /Catalog /Pages 2 0 R >>");
  addObj("");
  const fontObjId = addObj("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>");

  const kids: string[] = [];
  for (const streamContent of pageStreams) {
    const contentId = addObj(
      `<< /Length ${streamContent.length} >>\nstream\n${streamContent}\nendstream`
    );
    const pageId = addObj(
      `<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 ${fontObjId} 0 R >> >> /Contents ${contentId} 0 R >>`
    );
    kids.push(`${pageId} 0 R`);
  }

  objects[1] = `<< /Type /Pages /Kids [${kids.join(" ")}] /Count ${kids.length} >>`;

  let out = "%PDF-1.7\n";
  const offsets: number[] = [0];
  for (let i = 0; i < objects.length; i++) {
    offsets.push(out.length);
    out += `${i + 1} 0 obj\n${objects[i]}\nendobj\n`;
  }

  const xrefOffset = out.length;
  out += `xref\n0 ${objects.length + 1}\n`;
  out += "0000000000 65535 f \n";
  for (let i = 1; i < offsets.length; i++) {
    out += `${String(offsets[i]).padStart(10, "0")} 00000 n \n`;
  }
  out += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xrefOffset}\n%%EOF\n`;
  return fromLatin1(out);
}
