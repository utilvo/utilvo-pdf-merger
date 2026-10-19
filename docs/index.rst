utilvo-pdf-merger Documentation
===============================

``utilvo-pdf-merger`` is a lightweight, zero-dependency multi-language library for inspecting PDF binary headers (``%PDF-1.x``), counting leaf ``/Type /Page`` dictionary objects, validating ``xref`` tables and ``%%EOF`` markers, and merging multiple PDF byte streams into a consolidated document.

Built as the open-source companion library for the `Merge PDF <https://utilvo.com/pdf-tools/merge-pdf>`_ document processing utility, ``utilvo-pdf-merger`` allows developers to pre-validate PDF buffers, count total pages across multi-file batches, and concatenate PDF streams programmatically.

* **Online Utility:** `Merge PDF <https://utilvo.com/pdf-tools/merge-pdf>`_
* **Source Code Repository:** `https://github.com/utilvo/utilvo-pdf-merger <https://github.com/utilvo/utilvo-pdf-merger>`_

How It Works
------------

1. **Header & Integrity Inspection (``inspect_pdf``):** Reads the first 1,024 bytes of each buffer to verify the ``%PDF-1.x`` specification header and scans the trailer for a valid ``%%EOF`` marker.
2. **Page Tree Counting (``count_pdf_pages``):** Scans indirect dictionary objects matching ``/Type /Page`` to count leaf page nodes while excluding parent ``/Type /Pages`` containers.
3. **Indirect Object Renumbering & ``xref`` Reconstruction (``merge_pdf_bytes``):** Extracts page content streams across all input documents, assigns sequential object IDs under a unified ``/Type /Pages`` root array (``/Kids [...]``), and calculates exact byte offsets to emit a standards-compliant ``xref`` table and ``trailer`` dictionary.

Installation
------------

Python (PyPI)::

    pip install utilvo-pdf-merger

Node.js (npm)::

    npm install utilvo-pdf-merger

Rust (Crates.io)::

    cargo add utilvo-pdf-merger

Go::

    go get github.com/utilvo/utilvo-pdf-merger

Usage Example
-------------

.. code-block:: python

    from utilvo_pdf_merger import inspect_pdf, count_pdf_pages, merge_pdf_bytes

    info = inspect_pdf(pdf_bytes)
    print(info["version"], info["page_count"], info["is_valid"])

    merged_pdf = merge_pdf_bytes([doc_a_bytes, doc_b_bytes])
