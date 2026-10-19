<?php

declare(strict_types=1);

namespace Utilvo\PdfMerger;

final class PdfMerger
{
    public static function countPages(string $pdfBytes): int
    {
        return (int) preg_match_all('/\/Type\s*\/Page\b(?!s)/', $pdfBytes);
    }

    public static function inspect(string $pdfBytes): array
    {
        $header = substr($pdfBytes, 0, 1024);
        $version = null;
        if (preg_match('/%PDF-(\d+\.\d+)/', $header, $m)) {
            $version = $m[1];
        }
        $hasEof = strpos($pdfBytes, '%%EOF') !== false;
        return [
            'is_valid' => $version !== null && $hasEof,
            'version' => $version,
            'page_count' => self::countPages($pdfBytes),
            'has_eof' => $hasEof,
            'byte_length' => strlen($pdfBytes),
        ];
    }

    public static function merge(array $documents): string
    {
        if (empty($documents)) {
            throw new \InvalidArgumentException('At least one PDF document is required.');
        }
        $streams = [];
        foreach ($documents as $doc) {
            if (preg_match_all('/stream\r?\n([\s\S]*?)\r?\nendstream/', (string) $doc, $m) && !empty($m[1])) {
                foreach ($m[1] as $s) {
                    $streams[] = $s;
                }
            } else {
                $streams[] = 'BT /F1 12 Tf 72 720 Td () Tj ET';
            }
        }

        $objects = [
            '<< /Type /Catalog /Pages 2 0 R >>',
            '',
            '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
        ];
        $kids = [];
        foreach ($streams as $streamContent) {
            $len = strlen($streamContent);
            $objects[] = "<< /Length {$len} >>\nstream\n{$streamContent}\nendstream";
            $contentId = count($objects);
            $objects[] = "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 3 0 R >> >> /Contents {$contentId} 0 R >>";
            $pageId = count($objects);
            $kids[] = "{$pageId} 0 R";
        }
        $objects[1] = '<< /Type /Pages /Kids [' . implode(' ', $kids) . '] /Count ' . count($kids) . ' >>';

        $out = "%PDF-1.7\n";
        $offsets = [0];
        foreach ($objects as $idx => $body) {
            $offsets[] = strlen($out);
            $objNum = $idx + 1;
            $out .= "{$objNum} 0 obj\n{$body}\nendobj\n";
        }
        $xrefOffset = strlen($out);
        $total = count($objects) + 1;
        $out .= "xref\n0 {$total}\n0000000000 65535 f \n";
        for ($i = 1; $i < count($offsets); $i++) {
            $out .= sprintf("%010d 00000 n \n", $offsets[$i]);
        }
        $out .= "trailer\n<< /Size {$total} /Root 1 0 R >>\nstartxref\n{$xrefOffset}\n%%EOF\n";
        return $out;
    }
}
