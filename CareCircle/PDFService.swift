import UIKit
import PDFKit

// MARK: - PDF generation (isolated; no Firebase)

enum PDFService {
    private static let margin: CGFloat = 50
    private static let pageWidth: CGFloat = 612
    private static let pageHeight: CGFloat = 792
    private static let lineSpacing: CGFloat = 6
    private static let titleFontSize: CGFloat = 22
    private static let headingFontSize: CGFloat = 14
    private static let bodyFontSize: CGFloat = 11

    /// Generates a care report PDF and saves it under Documents/CareReports/care-report-YYYY-MM-DD.pdf.
    /// Returns the file URL on success.
    static func generateCareReportPDF(
        draft: CareReportDraft,
        completionSummary: (completed: Int, total: Int),
        date: Date = Date()
    ) -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        let dateString = formatter.string(from: date)
        let fileName = "care-report-\(dateString).pdf"

        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let careReportsDir = dir.appendingPathComponent("CareReports", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: careReportsDir, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        let fileURL = careReportsDir.appendingPathComponent(fileName)

        let content = buildPDFContent(draft: draft, completionSummary: completionSummary, date: date)
        let pages = splitContentIntoPages(content)
        guard let data = renderPDFFromPageImages(pages) else { return nil }
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }

    private struct PDFLine {
        let text: String
        let fontSize: CGFloat
        let isBold: Bool
    }

    private static func buildPDFContent(
        draft: CareReportDraft,
        completionSummary: (completed: Int, total: Int),
        date: Date
    ) -> [PDFLine] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        dateFormatter.timeZone = TimeZone.current
        let dateDisplay = dateFormatter.string(from: date)

        var lines: [PDFLine] = [
            PDFLine(text: "Care Report", fontSize: titleFontSize, isBold: true),
            PDFLine(text: dateDisplay, fontSize: bodyFontSize, isBold: false),
            PDFLine(text: " ", fontSize: bodyFontSize, isBold: false),
            PDFLine(text: "Routine completion: \(completionSummary.completed) of \(completionSummary.total) completed today", fontSize: bodyFontSize, isBold: false),
            PDFLine(text: "Caregiving intensity: \(draft.intensity)", fontSize: bodyFontSize, isBold: false),
            PDFLine(text: " ", fontSize: bodyFontSize, isBold: false),
            PDFLine(text: "What felt most demanding today", fontSize: headingFontSize, isBold: true),
            PDFLine(text: formatMulti(draft.answers["q2"]), fontSize: bodyFontSize, isBold: false),
            PDFLine(text: " ", fontSize: bodyFontSize, isBold: false),
            PDFLine(text: "Usual routines today", fontSize: headingFontSize, isBold: true),
            PDFLine(text: (draft.answers["q3"] as? String) ?? "—", fontSize: bodyFontSize, isBold: false),
            PDFLine(text: " ", fontSize: bodyFontSize, isBold: false),
            PDFLine(text: "Unexpected or concerning", fontSize: headingFontSize, isBold: true),
            PDFLine(text: (draft.answers["q4"] as? String) ?? "—", fontSize: bodyFontSize, isBold: false)
        ]

        if (draft.answers["q4"] as? String) == "Yes",
           let note = draft.answers["q5"] as? String, !note.isEmpty {
            lines.append(PDFLine(text: "Details: \(note)", fontSize: bodyFontSize, isBold: false))
        }
        lines.append(PDFLine(text: " ", fontSize: bodyFontSize, isBold: false))
        lines.append(PDFLine(text: "Support needed", fontSize: headingFontSize, isBold: true))
        lines.append(PDFLine(text: (draft.answers["q6"] as? String) ?? "—", fontSize: bodyFontSize, isBold: false))
        lines.append(PDFLine(text: " ", fontSize: bodyFontSize, isBold: false))
        lines.append(PDFLine(text: "Note for social worker", fontSize: headingFontSize, isBold: true))
        lines.append(PDFLine(text: (draft.answers["q7"] as? String) ?? "—", fontSize: bodyFontSize, isBold: false))

        return lines
    }

    private static func formatMulti(_ value: Any?) -> String {
        guard let arr = value as? [String], !arr.isEmpty else { return "None selected" }
        return arr.joined(separator: ", ")
    }

    /// Split lines into pages (each page = array of lines that fit).
    private static func splitContentIntoPages(_ lines: [PDFLine]) -> [[PDFLine]] {
        let textWidth = pageWidth - 2 * margin
        let maxY = pageHeight - margin
        var pages: [[PDFLine]] = []
        var currentPage: [PDFLine] = []
        var y = margin

        for line in lines {
            let font = line.isBold
                ? UIFont.boldSystemFont(ofSize: line.fontSize)
                : UIFont.systemFont(ofSize: line.fontSize)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.black
            ]
            let text = line.text as NSString
            let size = text.boundingRect(
                with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                options: .usesLineFragmentOrigin,
                attributes: attrs,
                context: nil
            )
            let height = ceil(size.height) + lineSpacing

            if y + height > maxY, !currentPage.isEmpty {
                pages.append(currentPage)
                currentPage = []
                y = margin
            }
            currentPage.append(line)
            y += height
        }
        if !currentPage.isEmpty {
            pages.append(currentPage)
        }
        return pages
    }

    /// Render each page as an image (UIKit text drawing works in image context), then draw images into PDF.
    private static func renderPDFFromPageImages(_ pages: [[PDFLine]]) -> Data? {
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { pdfContext in
            let cgContext = pdfContext.cgContext
            let textWidth = pageWidth - 2 * margin

            for (pageIndex, pageLines) in pages.enumerated() {
                if pageIndex > 0 {
                    pdfContext.beginPage()
                }

                // Render this page's text into an image (UIKit drawing works reliably here)
                let image = renderPageLinesToImage(pageLines, textWidth: textWidth)
                guard let cgImage = image.cgImage else { continue }

                // PDF context has origin bottom-left; draw image right-side up
                cgContext.saveGState()
                cgContext.translateBy(x: 0, y: pageHeight)
                cgContext.scaleBy(x: 1, y: -1)
                cgContext.draw(cgImage, in: pageRect)
                cgContext.restoreGState()
            }
        }
    }

    /// Draw lines on a single page into a UIImage (top-left origin; UIKit text drawing works).
    private static func renderPageLinesToImage(_ lines: [PDFLine], textWidth: CGFloat) -> UIImage {
        let pageSize = CGSize(width: pageWidth, height: pageHeight)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        let imageRenderer = UIGraphicsImageRenderer(size: pageSize, format: format)

        return imageRenderer.image { context in
            let ctx = context.cgContext
            UIGraphicsPushContext(ctx)
            defer { UIGraphicsPopContext() }
            // White background
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: pageSize))

            var y = margin
            for line in lines {
                let font = line.isBold
                    ? UIFont.boldSystemFont(ofSize: line.fontSize)
                    : UIFont.systemFont(ofSize: line.fontSize)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.black
                ]
                let text = line.text as NSString
                let size = text.boundingRect(
                    with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                    options: .usesLineFragmentOrigin,
                    attributes: attrs,
                    context: nil
                )
                let height = ceil(size.height) + lineSpacing
                let rect = CGRect(x: margin, y: y, width: textWidth, height: height)
                text.draw(with: rect, options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
                y += height
            }
        }
    }
}
