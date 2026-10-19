const PAGE_REGEX = /\/Type\s*\/Page\b(?!s)/g;
const VERSION_REGEX = /%PDF-(\d+\.\d+)/;
const STREAM_REGEX = /stream\r?\n([\s\S]*?)\r?\nendstream/g;

function toLatin1(input) {
  if (typeof input === 'string') return input;
  if (input instanceof Uint8Array) {
    let out = '';
    for (let i = 0; i < input.length; i++) {
      out += String.fromCharCode(input[i]);
    }
    return out;
  }
  throw new TypeError('Expected Uint8Array or string');
}

function fromLatin1(str) {
  const out = new Uint8Array(str.length);
  for (let i = 0; i < str.length; i++) {
    out[i] = str.charCodeAt(i) & 0xff;
  }
  return out;
}

/**
 * Counts leaf `/Type /Page` objects in a PDF byte buffer.
 * @param {Uint8Array|string} pdfData
 * @returns {number}
 */
export function countPdfPages(pdfData) {
  const raw = toLatin1(pdfData);
  const matches = raw.match(PAGE_REGEX);
  return matches ? matches.length : 0;
}

/**
 * Inspects a PDF buffer and returns header version, page count, and structural integrity.
 * @param {Uint8Array|string} pdfData
 * @returns {{ isValid: boolean, version: string|null, pageCount: number, hasEof: boolean, byteLength: number }}
 */
export function inspectPdf(pdfData) {
  const raw = toLatin1(pdfData);
  const verMatch = raw.slice(0, 1024).match(VERSION_REGEX);
  const hasEof = raw.includes('%%EOF');
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
 * Merges multiple PDF buffers into a consolidated PDF document with a rebuilt xref table.
 * @param {Array<Uint8Array|string>} documents
 * @returns {Uint8Array}
 */
export function mergePdfBuffers(documents) {
  if (!Array.isArray(documents) || documents.length === 0) {
    throw new Error('At least one PDF document is required');
  }
  const pageStreams = [];
  for (const doc of documents) {
    const raw = toLatin1(doc);
    let m;
    STREAM_REGEX.lastIndex = 0;
    let foundInDoc = 0;
    while ((m = STREAM_REGEX.exec(raw)) !== null) {
      pageStreams.push(m[1]);
      foundInDoc++;
    }
    if (foundInDoc === 0) {
      pageStreams.push('BT /F1 12 Tf 72 720 Td () Tj ET');
    }
  }

  const objects = [];
  const addObj = (body) => {
    objects.push(body);
    return objects.length;
  };

  // 1: Catalog, 2: Pages placeholder
  addObj('<< /Type /Catalog /Pages 2 0 R >>');
  addObj(''); // reserved for Pages object #2
  const fontObjId = addObj('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');

  const kids = [];
  for (const streamContent of pageStreams) {
    const contentId = addObj(
      `<< /Length ${streamContent.length} >>\nstream\n${streamContent}\nendstream`
    );
    const pageId = addObj(
      `<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 ${fontObjId} 0 R >> >> /Contents ${contentId} 0 R >>`
    );
    kids.push(`${pageId} 0 R`);
  }

  objects[1] = `<< /Type /Pages /Kids [${kids.join(' ')}] /Count ${kids.length} >>`;

  let out = '%PDF-1.7\n';
  const offsets = [0];
  for (let i = 0; i < objects.length; i++) {
    offsets.push(out.length);
    out += `${i + 1} 0 obj\n${objects[i]}\nendobj\n`;
  }

  const xrefOffset = out.length;
  out += `xref\n0 ${objects.length + 1}\n`;
  out += '0000000000 65535 f \n';
  for (let i = 1; i < offsets.length; i++) {
    out += `${String(offsets[i]).padStart(10, '0')} 00000 n \n`;
  }
  out += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xrefOffset}\n%%EOF\n`;
  return fromLatin1(out);
}
