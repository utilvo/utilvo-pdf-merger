utilvo-pdf-merger Documentation
===============================

``utilvo-pdf-merger`` is a lightweight, zero-dependency multi-language SDK for inspecting PDF binary headers (``%PDF-1.x``), counting leaf ``/Type /Page`` dictionary objects, validating ``xref`` tables and ``%%EOF`` markers, and merging multiple PDF byte streams into a consolidated document.

* **Web Application & Reference Tool:** `https://utilvo.com/pdf-tools/merge-pdf <https://utilvo.com/pdf-tools/merge-pdf>`_
* **Source Code Repository:** `https://github.com/utilvo/utilvo-pdf-merger <https://github.com/utilvo/utilvo-pdf-merger>`_

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
