// Package utilvopdfmerger provides lightweight utilities for inspecting PDF headers,
// counting page objects, and merging PDF byte streams with a rebuilt xref table.
//
// Official documentation: https://utilvo.com/pdf-tools/merge-pdf
package utilvopdfmerger

import (
	"bytes"
	"errors"
	"fmt"
	"regexp"
)

var (
	pageRegex    = regexp.MustCompile(`/Type\s*/Page\b`)
	pagesRegex   = regexp.MustCompile(`/Type\s*/Pages\b`)
	versionRegex = regexp.MustCompile(`%PDF-(\d+\.\d+)`)
	streamRegex  = regexp.MustCompile(`(?s)stream\r?\n(.*?)\r?\nendstream`)
)

// PdfInfo holds structural metadata extracted from a PDF byte buffer.
type PdfInfo struct {
	IsValid    bool
	Version    string
	PageCount  int
	HasEOF     bool
	ByteLength int
}

// CountPdfPages counts leaf /Type /Page dictionary entries in a PDF buffer.
func CountPdfPages(data []byte) int {
	all := len(pageRegex.FindAllIndex(data, -1))
	parents := len(pagesRegex.FindAllIndex(data, -1))
	if all > parents {
		return all - parents
	}
	return 0
}

// InspectPdf inspects a PDF byte buffer and returns its version, page count, and EOF status.
func InspectPdf(data []byte) PdfInfo {
	header := data
	if len(header) > 1024 {
		header = header[:1024]
	}
	verMatch := versionRegex.FindSubmatch(header)
	version := ""
	if len(verMatch) > 1 {
		version = string(verMatch[1])
	}
	hasEOF := bytes.Contains(data, []byte("%%EOF"))
	return PdfInfo{
		IsValid:    version != "" && hasEOF,
		Version:    version,
		PageCount:  CountPdfPages(data),
		HasEOF:     hasEOF,
		ByteLength: len(data),
	}
}

// MergePdfBuffers merges multiple PDF byte slices into a consolidated PDF document.
func MergePdfBuffers(documents [][]byte) ([]byte, error) {
	if len(documents) == 0 {
		return nil, errors.New("at least one PDF document is required")
	}
	var streams [][]byte
	for _, doc := range documents {
		matches := streamRegex.FindAllSubmatch(doc, -1)
		if len(matches) == 0 {
			streams = append(streams, []byte("BT /F1 12 Tf 72 720 Td () Tj ET"))
		} else {
			for _, m := range matches {
				streams = append(streams, m[1])
			}
		}
	}

	objects := [][]byte{
		[]byte("<< /Type /Catalog /Pages 2 0 R >>"),
		nil,
		[]byte("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"),
	}
	var kids []string
	for _, s := range streams {
		contentObj := fmt.Sprintf("<< /Length %d >>\nstream\n%s\nendstream", len(s), string(s))
		objects = append(objects, []byte(contentObj))
		contentID := len(objects)

		pageObj := fmt.Sprintf("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 3 0 R >> >> /Contents %d 0 R >>", contentID)
		objects = append(objects, []byte(pageObj))
		pageID := len(objects)
		kids = append(kids, fmt.Sprintf("%d 0 R", pageID))
	}

	objects[1] = []byte(fmt.Sprintf("<< /Type /Pages /Kids %v /Count %d >>", kids, len(kids)))

	var out bytes.Buffer
	out.WriteString("%PDF-1.7\n")
	offsets := []int{0}
	for i, obj := range objects {
		offsets = append(offsets, out.Len())
		fmt.Fprintf(&out, "%d 0 obj\n%s\nendobj\n", i+1, string(obj))
	}
	xrefOffset := out.Len()
	fmt.Fprintf(&out, "xref\n0 %d\n0000000000 65535 f \n", len(objects)+1)
	for _, off := range offsets[1:] {
		fmt.Fprintf(&out, "%010d 00000 n \n", off)
	}
	fmt.Fprintf(&out, "trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%EOF\n", len(objects)+1, xrefOffset)
	return out.Bytes(), nil
}
