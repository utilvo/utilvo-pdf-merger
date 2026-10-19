import Foundation

public struct PdfInspectionResult {
    public let isValid: Bool
    public let version: String?
    public let pageCount: Int
    public let hasEOF: Bool
    public let byteLength: Int
}

public enum UtilvoPdfMerger {
    public static func countPages(_ data: Data) -> Int {
        let raw = String(decoding: data, as: UTF8.self)
        let parts = raw.components(separatedBy: "/Type")
        var count = 0
        for part in parts.dropFirst() {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("/Page") && !trimmed.hasPrefix("/Pages") {
                count += 1
            }
        }
        return count
    }

    public static func inspect(_ data: Data) -> PdfInspectionResult {
        let raw = String(decoding: data, as: UTF8.self)
        let hasEOF = raw.contains("%%EOF")
        var version: String? = nil
        if let range = raw.range(of: "%PDF-") {
            let sub = raw[range.upperBound...]
            let ver = String(sub.prefix(3))
            if !ver.isEmpty {
                version = ver
            }
        }
        return PdfInspectionResult(
            isValid: version != nil && hasEOF,
            version: version,
            pageCount: countPages(data),
            hasEOF: hasEOF,
            byteLength: data.count
        )
    }
}
