import UIKit

// MARK: - Report as JPEG image (no PDF, no Firebase)

/// Generates the care report as a single JPEG image. Call from main thread.
enum ReportImageService {
    private static let margin: CGFloat = 40
    private static let width: CGFloat = 600
    private static let lineSpacing: CGFloat = 8
    private static let titleFontSize: CGFloat = 24
    private static let headingFontSize: CGFloat = 16
    private static let bodyFontSize: CGFloat = 14

    /// Generates report image and saves to Documents/CareReports/care-report-YYYY-MM-DD.jpg.
    /// Returns file URL on success. Must be called on main thread (UIKit drawing).
    static func generateReportImage(
        draft: CareReportDraft,
        completionSummary: (completed: Int, total: Int),
        date: Date = Date()
    ) -> URL? {
        let lines = buildContent(draft: draft, completionSummary: completionSummary, date: date)
        let totalHeight = computeHeight(lines: lines)
        guard totalHeight > 0 else { return nil }

        let size = CGSize(width: width, height: totalHeight)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        let image = renderer.image { context in
            let ctx = context.cgContext
            UIGraphicsPushContext(ctx)
            defer { UIGraphicsPopContext() }

            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let textWidth = width - 2 * margin
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
                let textSize = text.boundingRect(
                    with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                    options: .usesLineFragmentOrigin,
                    attributes: attrs,
                    context: nil
                )
                let height = ceil(textSize.height) + lineSpacing
                let rect = CGRect(x: margin, y: y, width: textWidth, height: height)
                text.draw(with: rect, options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
                y += height
            }
        }

        guard let jpegData = image.jpegData(compressionQuality: 0.9) else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        let dateString = formatter.string(from: date)
        let fileName = "care-report-\(dateString).jpg"

        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let careReportsDir = dir.appendingPathComponent("CareReports", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: careReportsDir, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        let fileURL = careReportsDir.appendingPathComponent(fileName)
        do {
            try jpegData.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }

    private struct Line {
        let text: String
        let fontSize: CGFloat
        let isBold: Bool
    }

    private static func buildContent(
        draft: CareReportDraft,
        completionSummary: (completed: Int, total: Int),
        date: Date
    ) -> [Line] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeZone = TimeZone.current
        let dateDisplay = dateFormatter.string(from: date)

        var lines: [Line] = [
            Line(text: "Care Report", fontSize: titleFontSize, isBold: true),
            Line(text: dateDisplay, fontSize: bodyFontSize, isBold: false),
            Line(text: " ", fontSize: bodyFontSize, isBold: false),
            Line(text: "Routine completion: \(completionSummary.completed) of \(completionSummary.total) completed today", fontSize: bodyFontSize, isBold: false),
            Line(text: "Caregiving intensity: \(draft.intensity)", fontSize: bodyFontSize, isBold: false),
            Line(text: " ", fontSize: bodyFontSize, isBold: false),
            Line(text: "What felt most demanding today?", fontSize: headingFontSize, isBold: true),
            Line(text: formatMulti(draft.answers["q2"]), fontSize: bodyFontSize, isBold: false),
            Line(text: " ", fontSize: bodyFontSize, isBold: false),
            Line(text: "Were you able to complete your usual routines today?", fontSize: headingFontSize, isBold: true),
            Line(text: (draft.answers["q3"] as? String) ?? "—", fontSize: bodyFontSize, isBold: false),
            Line(text: " ", fontSize: bodyFontSize, isBold: false),
            Line(text: "Did anything unexpected or concerning happen today?", fontSize: headingFontSize, isBold: true),
            Line(text: (draft.answers["q4"] as? String) ?? "—", fontSize: bodyFontSize, isBold: false)
        ]
        if (draft.answers["q4"] as? String) == "Yes",
           let note = draft.answers["q5"] as? String, !note.isEmpty {
            lines.append(Line(text: "Details: \(note)", fontSize: bodyFontSize, isBold: false))
        }
        lines.append(Line(text: " ", fontSize: bodyFontSize, isBold: false))
        lines.append(Line(text: "What kind of support would help most right now?", fontSize: headingFontSize, isBold: true))
        lines.append(Line(text: (draft.answers["q6"] as? String) ?? "—", fontSize: bodyFontSize, isBold: false))
        lines.append(Line(text: " ", fontSize: bodyFontSize, isBold: false))
        lines.append(Line(text: "Anything you want a social worker to know?", fontSize: headingFontSize, isBold: true))
        lines.append(Line(text: (draft.answers["q7"] as? String) ?? "—", fontSize: bodyFontSize, isBold: false))
        return lines
    }

    private static func formatMulti(_ value: Any?) -> String {
        guard let arr = value as? [String], !arr.isEmpty else { return "None selected" }
        return arr.joined(separator: ", ")
    }

    private static func computeHeight(lines: [Line]) -> CGFloat {
        let textWidth = width - 2 * margin
        var y = margin
        for line in lines {
            let font = line.isBold ? UIFont.boldSystemFont(ofSize: line.fontSize) : UIFont.systemFont(ofSize: line.fontSize)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
            let text = line.text as NSString
            let size = text.boundingRect(with: CGSize(width: textWidth, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
            y += ceil(size.height) + lineSpacing
        }
        return y + margin
    }
}
