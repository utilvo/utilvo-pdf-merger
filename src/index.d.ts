export interface PdfInspectionResult {
  isValid: boolean;
  version: string | null;
  pageCount: number;
  hasEof: boolean;
  byteLength: number;
}

export function countPdfPages(pdfData: Uint8Array | string): number;
export function inspectPdf(pdfData: Uint8Array | string): PdfInspectionResult;
export function mergePdfBuffers(documents: Array<Uint8Array | string>): Uint8Array;
