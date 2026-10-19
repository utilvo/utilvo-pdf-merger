//! Lightweight library for inspecting PDF binary headers, counting pages,
//! and merging multiple PDF byte streams into a unified document.

/// Metadata extracted from a raw PDF byte buffer.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PdfInspection {
    pub is_valid: bool,
    pub version: Option<String>,
    pub page_count: usize,
    pub has_eof: bool,
    pub byte_length: usize,
}

/// Counts leaf `/Type /Page` entries in a PDF byte buffer.
pub fn count_pdf_pages(data: &[u8]) -> usize {
    let text = String::from_utf8_lossy(data);
    let mut count = 0;
    for part in text.split("/Type") {
        let trimmed = part.trim_start();
        if let Some(rest) = trimmed.strip_prefix("/Page") {
            if !rest.starts_with('s') && !rest.starts_with(|c: char| c.is_ascii_alphabetic()) {
                count += 1;
            }
        }
    }
    count
}

/// Inspects a PDF byte slice and extracts header version, page count, and EOF status.
pub fn inspect_pdf(data: &[u8]) -> PdfInspection {
    let header_len = data.len().min(1024);
    let header = String::from_utf8_lossy(&data[..header_len]);
    let version = header.find("%PDF-").and_then(|idx| {
        let rest = &header[idx + 5..];
        let ver: String = rest
            .chars()
            .take_while(|c| c.is_ascii_digit() || *c == '.')
            .collect();
        if ver.is_empty() { None } else { Some(ver) }
    });
    let full = String::from_utf8_lossy(data);
    let has_eof = full.contains("%%EOF");
    let page_count = count_pdf_pages(data);
    PdfInspection {
        is_valid: version.is_some() && has_eof,
        version,
        page_count,
        has_eof,
        byte_length: data.len(),
    }
}

/// Merges multiple PDF byte slices into a consolidated PDF byte vector with a rebuilt `xref` table.
pub fn merge_pdf_buffers(documents: &[&[u8]]) -> Vec<u8> {
    let mut objects: Vec<String> = vec![
        "<< /Type /Catalog /Pages 2 0 R >>".to_string(),
        String::new(),
        "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>".to_string(),
    ];
    let mut kids: Vec<String> = Vec::new();

    for doc in documents {
        let raw = String::from_utf8_lossy(doc);
        let stream_body = if let (Some(s), Some(e)) = (raw.find("stream"), raw.find("endstream")) {
            if e > s + 6 {
                raw[s + 6..e].trim_matches(&['\r', '\n'][..]).to_string()
            } else {
                "BT /F1 12 Tf 72 720 Td () Tj ET".to_string()
            }
        } else {
            "BT /F1 12 Tf 72 720 Td () Tj ET".to_string()
        };

        objects.push(format!(
            "<< /Length {} >>\nstream\n{}\nendstream",
            stream_body.len(),
            stream_body
        ));
        let content_id = objects.len();

        objects.push(format!(
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 3 0 R >> >> /Contents {} 0 R >>",
            content_id
        ));
        let page_id = objects.len();
        kids.push(format!("{} 0 R", page_id));
    }

    objects[1] = format!(
        "<< /Type /Pages /Kids [{}] /Count {} >>",
        kids.join(" "),
        kids.len()
    );

    let mut out = String::from("%PDF-1.7\n");
    let mut offsets: Vec<usize> = vec![0];
    for (i, obj) in objects.iter().enumerate() {
        offsets.push(out.len());
        out.push_str(&format!("{} 0 obj\n{}\nendobj\n", i + 1, obj));
    }
    let xref_offset = out.len();
    out.push_str(&format!("xref\n0 {}\n0000000000 65535 f \n", objects.len() + 1));
    for off in offsets.iter().skip(1) {
        out.push_str(&format!("{:010} 00000 n \n", off));
    }
    out.push_str(&format!(
        "trailer\n<< /Size {} /Root 1 0 R >>\nstartxref\n{}\n%%EOF\n",
        objects.len() + 1,
        xref_offset
    ));
    out.into_bytes()
}
