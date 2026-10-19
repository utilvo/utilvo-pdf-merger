"""Lightweight PDF binary inspector, page counter, and multi-document stream merger."""

from __future__ import annotations
import re
from typing import Iterable, List, Dict, Any, Union

__version__ = "1.0.0"

_PAGE_RE = re.compile(rb"/Type\s*/Page\b(?!s)")
_VERSION_RE = re.compile(rb"%PDF-(\d+\.\d+)")
_STREAM_RE = re.compile(rb"stream\r?\n([\s\S]*?)\r?\nendstream")


def _to_bytes(data: Union[bytes, bytearray, str]) -> bytes:
    if isinstance(data, bytes):
        return data
    if isinstance(data, bytearray):
        return bytes(data)
    if isinstance(data, str):
        return data.encode("latin1")
    raise TypeError("Expected bytes or str")


def count_pdf_pages(pdf_data: Union[bytes, bytearray, str]) -> int:
    """Counts leaf `/Type /Page` entries in a PDF byte buffer."""
    raw = _to_bytes(pdf_data)
    return len(_PAGE_RE.findall(raw))


def inspect_pdf(pdf_data: Union[bytes, bytearray, str]) -> Dict[str, Any]:
    """Inspects a PDF byte stream and returns version, page count, and EOF validity."""
    raw = _to_bytes(pdf_data)
    ver_match = _VERSION_RE.search(raw[:1024])
    has_eof = b"%%EOF" in raw
    page_count = count_pdf_pages(raw)
    return {
        "is_valid": bool(ver_match and has_eof),
        "version": ver_match.group(1).decode("ascii") if ver_match else None,
        "page_count": page_count,
        "has_eof": has_eof,
        "byte_length": len(raw),
    }


def merge_pdf_bytes(documents: Iterable[Union[bytes, bytearray, str]]) -> bytes:
    """Merges multiple PDF byte streams into a single PDF document with a rebuilt xref table."""
    docs: List[bytes] = [_to_bytes(d) for d in documents]
    if not docs:
        raise ValueError("At least one PDF document is required")

    page_streams: List[bytes] = []
    for raw in docs:
        streams = _STREAM_RE.findall(raw)
        if streams:
            page_streams.extend(streams)
        else:
            page_streams.append(b"BT /F1 12 Tf 72 720 Td () Tj ET")

    objects: List[bytes] = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"",  # placeholder for Pages object #2
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    ]
    font_obj_id = 3
    kids: List[bytes] = []

    for stream_content in page_streams:
        objects.append(
            b"<< /Length " + str(len(stream_content)).encode("ascii") + b" >>\nstream\n" + stream_content + b"\nendstream"
        )
        content_id = len(objects)
        objects.append(
            f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 {font_obj_id} 0 R >> >> /Contents {content_id} 0 R >>".encode("ascii")
        )
        page_id = len(objects)
        kids.append(f"{page_id} 0 R".encode("ascii"))

    objects[1] = b"<< /Type /Pages /Kids [" + b" ".join(kids) + f"] /Count {len(kids)} >>".encode("ascii")

    out = bytearray(b"%PDF-1.7\n")
    offsets: List[int] = [0]
    for idx, obj_body in enumerate(objects, start=1):
        offsets.append(len(out))
        out.extend(f"{idx} 0 obj\n".encode("ascii"))
        out.extend(obj_body)
        out.extend(b"\nendobj\n")

    xref_offset = len(out)
    out.extend(f"xref\n0 {len(objects) + 1}\n".encode("ascii"))
    out.extend(b"0000000000 65535 f \n")
    for off in offsets[1:]:
        out.extend(f"{off:010d} 00000 n \n".encode("ascii"))
    out.extend(
        f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\nstartxref\n{xref_offset}\n%%EOF\n".encode("ascii")
    )
    return bytes(out)
