import Foundation
import AppKit
import Combine
import UniformTypeIdentifiers

struct InventoryItem: Identifiable, Codable {
    var id: String { name }
    let name: String
    let detail: String
    let result: String
}

struct ManualTest: Identifiable, Codable {
    let id: String
    let category: String
    let title: String
    let instructions: String
    var status: TestStatus = .notRun
}

enum TestStatus: String, Codable, CaseIterable {
    case notRun = "Neatlikta"
    case passed = "Veikia"
    case failed = "Gedimas"
    case notApplicable = "Netaikoma"
}

@MainActor
final class DiagnosticsModel: ObservableObject {
    @Published var inventory: [InventoryItem] = []
    @Published var tests = Self.defaultTests
    @Published var isScanning = false
    @Published var lastScan: Date?
    @Published var scanError: String?
    @Published var reportError: String?

    var passedCount: Int { tests.filter { $0.status == .passed }.count }
    var failedCount: Int { tests.filter { $0.status == .failed }.count }
    var remainingCount: Int { tests.filter { $0.status == .notRun }.count }

    func setStatus(_ status: TestStatus, for testID: String) {
        guard let index = tests.firstIndex(where: { $0.id == testID }) else { return }
        tests[index].status = status
    }

    func runScan() {
        guard !isScanning else { return }
        isScanning = true
        scanError = nil
        Task.detached(priority: .userInitiated) { [weak self] in
            let result = HardwareScanner.scan()
            await MainActor.run {
                self?.inventory = result.items
                self?.scanError = result.error
                self?.lastScan = Date()
                self?.isScanning = false
            }
        }
    }

    func exportReport() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "MacCheck-ataskaita-\(Self.dateStamp()).json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try encoder.encode(currentReport()).write(to: url, options: .atomic)
        } catch {
            reportError = "Nepavyko išsaugoti JSON ataskaitos: \(error.localizedDescription)"
        }
    }

    func exportPDF() {
        let panel = NSSavePanel()
        panel.title = "Išsaugoti MacCheck PDF ataskaitą"
        panel.nameFieldStringValue = "MacCheck-ataskaita-\(Self.dateStamp()).pdf"
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let pageSize = NSSize(width: 595.28, height: 841.89)
            let reportView = DiagnosticPDFView(report: currentReport(), pageSize: pageSize)
            try reportView.dataWithPDF(inside: reportView.bounds).write(to: url, options: .atomic)
        } catch {
            reportError = "Nepavyko sukurti PDF ataskaitos: \(error.localizedDescription)"
        }
    }

    func printReport() {
        let pageSize = NSSize(width: 595.28, height: 841.89)
        let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
        printInfo.paperSize = pageSize
        printInfo.topMargin = 0
        printInfo.bottomMargin = 0
        printInfo.leftMargin = 0
        printInfo.rightMargin = 0
        let reportView = DiagnosticPDFView(report: currentReport(), pageSize: pageSize)
        let operation = NSPrintOperation(view: reportView, printInfo: printInfo)
        operation.jobTitle = "MacCheck patikros ataskaita"
        operation.showsPrintPanel = true
        _ = operation.run()
    }

    private func currentReport() -> DiagnosticReport {
        let formatter = ISO8601DateFormatter()
        return DiagnosticReport(
            createdAt: formatter.string(from: Date()),
            scanCompletedAt: lastScan.map { formatter.string(from: $0) },
            inventory: inventory,
            manualTests: tests
        )
    }

    private static func dateStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter.string(from: Date())
    }

    private static let defaultTests: [ManualTest] = [
        .init(id: "display", category: "Ekranas", title: "Ekranas ir pikseliai", instructions: "Atverk spalvų testą. Peržiūrėk visą ekraną baltame, juodame, raudoname, žaliame ir mėlyname fone. Ieškok dėmių, linijų, mirgėjimo ir neveikiančių pikselių."),
        .init(id: "keyboard", category: "Klaviatūra", title: "Klavišai", instructions: "Paspausk klavišus klaviatūros teste. Patikrink kiekvieną klavišą, įskaitant Fn, Shift, Control, Option, Command, rodykles ir Touch ID."),
        .init(id: "trackpad", category: "Įvestis", title: "Trackpad", instructions: "Patikrink žymeklio judėjimą, paspaudimą, Force Touch, dviejų pirštų slinkimą, priartinimą ir gestus. Jei įmanoma, pakartok atjungęs pelę."),
        .init(id: "camera", category: "Kamera", title: "Kamera", instructions: "Atverk FaceTime arba Photo Booth. Patvirtink vaizdą, fokusavimą, ekspoziciją ir kameros indikatoriaus veikimą."),
        .init(id: "microphone", category: "Garsas", title: "Mikrofonas", instructions: "Sistemos nustatymuose pasirink vidinį mikrofoną, įrašyk trumpą balsą ir paklausyk įrašo. Patikrink kairįjį ir dešinįjį kanalus, jei jie atskiri."),
        .init(id: "speakers", category: "Garsas", title: "Garsiakalbiai ir ausinės", instructions: "Paleisk garsą mažesniu garsumu. Patikrink abu garsiakalbius, išvesties pasirinkimą, ausinių lizdą ir garsumo klavišus."),
        .init(id: "wifi", category: "Ryšys", title: "Wi‑Fi", instructions: "Prisijunk prie žinomo tinklo. Patikrink stabilų interneto ryšį, atsijungimą ir prisijungimą iš naujo."),
        .init(id: "bluetooth", category: "Ryšys", title: "Bluetooth", instructions: "Įjunk Bluetooth, suporuok žinomą įrenginį, patikrink ryšį ir atsijungimą."),
        .init(id: "ports", category: "Jungtys", title: "USB‑C / Thunderbolt / MagSafe / SD / HDMI", instructions: "Patikrink kiekvieną įrenginyje esančią jungtį su žinomu veikiančiu priedu. Patikrink įkrovimą ir duomenų perdavimą; nekeisk kabelio prievado bandymo metu."),
        .init(id: "charging", category: "Maitinimas", title: "Įkrovimas ir baterija", instructions: "Patikrink įkrovimą su tinkamu adapteriu, MagSafe indikatorių (jei yra), baterijos procento kitimą ir veikimą atjungus maitinimą."),
        .init(id: "sleep", category: "Maitinimas", title: "Miego režimas ir dangtis", instructions: "Užverk dangtį, palauk, atverk ir patikrink pabudimą, ekraną, garsą, Wi‑Fi bei klaviatūros apšvietimą."),
        .init(id: "touchid", category: "Saugumas", title: "Touch ID", instructions: "Patikrink Touch ID prisijungimą arba atrakink Sistemos nustatymus. Patikrink ir maitinimo mygtuko veikimą."),
        .init(id: "thermal", category: "Aušinimas", title: "Ventiliatoriai ir temperatūra", instructions: "Paklausyk neįprastų garsų, patikrink oro srautą ir ar nėra netikėto perkaitimo. Neuždenk ventiliacijos angų."),
        .init(id: "audiojack", category: "Jungtys", title: "Garso lizdas", instructions: "Prijunk žinomas veikiančias ausines ir patikrink, ar sistema parenka išvestį bei groja abu kanalus."),
    ]
}

struct DiagnosticReport: Codable {
    let createdAt: String
    let scanCompletedAt: String?
    let inventory: [InventoryItem]
    let manualTests: [ManualTest]
}

private final class DiagnosticPDFView: NSView {
    private let report: DiagnosticReport
    private let pageSize: NSSize
    override var isFlipped: Bool { true }

    init(report: DiagnosticReport, pageSize: NSSize) {
        self.report = report
        self.pageSize = pageSize
        super.init(frame: NSRect(origin: .zero, size: pageSize))
    }

    required init?(coder: NSCoder) { return nil }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        NSBezierPath(rect: bounds).fill()
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: pageSize.width, height: 5)).fill()

        let margin: CGFloat = 40
        let width = pageSize.width - margin * 2
        _ = drawText("✓ MacCheck", x: margin, y: 24, width: width * 0.55,
                     font: .systemFont(ofSize: 18, weight: .bold), color: .systemBlue)
        _ = drawText("Įrenginių diagnostika", x: margin, y: 47, width: width,
                     font: .systemFont(ofSize: 8), color: .secondaryLabel)
        var y: CGFloat = 64
        drawRule(at: y, x: margin, width: width)
        y += 13
        y += drawText("MacBook patikros ataskaita", x: margin, y: y, width: width,
                      font: .systemFont(ofSize: 18, weight: .bold), color: .label)
        let created = formattedDate(report.createdAt)
        _ = drawText("Ataskaitos ID: MC-\(Self.dateStamp(report.createdAt))  ·  Data: \(created)",
                     x: margin, y: y + 2, width: width,
                     font: .systemFont(ofSize: 8.5), color: .secondaryLabel)
        y += 33

        let passed = report.manualTests.filter { $0.status == .passed }.count
        let failed = report.manualTests.filter { $0.status == .failed }.count
        let pending = report.manualTests.filter { $0.status == .notRun }.count
        let applicable = report.manualTests.count - report.manualTests.filter { $0.status == .notApplicable }.count
        let summaryText = "Sistemos informacijos įrašai: \(report.inventory.count)  ·  Nuskaityta: \(report.scanCompletedAt.map(formattedDate) ?? "neatlikta")"
        drawCard(NSRect(x: margin, y: y, width: width, height: 34), fill: NSColor(calibratedWhite: 0.96, alpha: 1))
        _ = drawText(summaryText, x: margin + 10, y: y + 10, width: width - 20,
                     font: .systemFont(ofSize: 8), color: .secondaryLabel)
        y += 43

        let metricWidth = (width - 16) / 3
        let metrics: [(String, String, NSColor)] = [
            ("\(passed) / \(applicable)", "Veikia", .systemGreen),
            ("\(failed)", "Gedimai", .systemRed),
            ("\(pending)", "Neatlikta", .secondaryLabel)
        ]
        for (index, metric) in metrics.enumerated() {
            let x = margin + CGFloat(index) * (metricWidth + 8)
            drawCard(NSRect(x: x, y: y, width: metricWidth, height: 43), fill: NSColor(calibratedWhite: 0.98, alpha: 1))
            _ = drawText(metric.0, x: x + 9, y: y + 5, width: metricWidth - 18,
                         font: .systemFont(ofSize: 15, weight: .bold), color: metric.2)
            _ = drawText(metric.1, x: x + 9, y: y + 25, width: metricWidth - 18,
                         font: .systemFont(ofSize: 7.5), color: .secondaryLabel)
        }
        y += 55
        _ = drawText("Atlikti rankiniai testai", x: margin, y: y, width: width,
                     font: .systemFont(ofSize: 11, weight: .bold), color: .label)
        y += 19
        drawCard(NSRect(x: margin, y: y, width: width, height: 20), fill: NSColor(calibratedWhite: 0.95, alpha: 1))
        _ = drawText("TESTAS", x: margin + 8, y: y + 6, width: width * 0.68,
                     font: .systemFont(ofSize: 7, weight: .bold), color: .secondaryLabel)
        _ = drawText("REZULTATAS", x: margin + width * 0.70, y: y + 6, width: width * 0.28,
                     font: .systemFont(ofSize: 7, weight: .bold), color: .secondaryLabel, alignment: .right)
        y += 20

        let rowHeight = min(27, max(19, (pageSize.height - y - 85) / CGFloat(max(report.manualTests.count, 1))))
        for (index, test) in report.manualTests.enumerated() {
            let row = NSRect(x: margin, y: y, width: width, height: rowHeight)
            if index.isMultiple(of: 2) { drawCard(row, fill: NSColor(calibratedWhite: 0.985, alpha: 1)) }
            let titleY = y + max(3, (rowHeight - 10) / 2)
            _ = drawText(test.title, x: margin + 8, y: titleY, width: width * 0.65,
                         font: .systemFont(ofSize: 8.5, weight: .medium), color: .label)
            let statusColor: NSColor = switch test.status {
            case .passed: .systemGreen
            case .failed: .systemRed
            case .notApplicable: .secondaryLabel
            case .notRun: .systemOrange
            }
            _ = drawText(test.status.rawValue.uppercased(), x: margin + width * 0.70, y: titleY,
                         width: width * 0.28, font: .systemFont(ofSize: 7.5, weight: .bold),
                         color: statusColor, alignment: .right)
            y += rowHeight
        }

        let footerY = pageSize.height - 45
        drawRule(at: footerY, x: margin, width: width)
        _ = drawText("Automatinis nuskaitymas rodo macOS aptiktą informaciją; jis savaime nepatvirtina komponentų veikimo.",
                     x: margin, y: footerY + 8, width: width,
                     font: .systemFont(ofSize: 7), color: .secondaryLabel)
        _ = drawText("MacCheck  ·  1", x: margin, y: pageSize.height - 20, width: width,
                     font: .systemFont(ofSize: 7), color: .tertiaryLabel)
    }

    @discardableResult
    private func drawText(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat,
                          font: NSFont, color: NSColor, alignment: NSTextAlignment = .left) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: color, .paragraphStyle: paragraph
        ]
        let value = text as NSString
        let measured = value.boundingRect(
            with: NSSize(width: max(width, 1), height: 500),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
        let height = ceil(measured.height)
        value.draw(in: NSRect(x: x, y: y, width: width, height: height), withAttributes: attributes)
        return height
    }

    private func drawCard(_ rect: NSRect, fill: NSColor) {
        fill.setFill()
        NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5).fill()
    }

    private func drawRule(at y: CGFloat, x: CGFloat, width: CGFloat) {
        NSColor.separatorColor.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 0.6
        path.move(to: NSPoint(x: x, y: y))
        path.line(to: NSPoint(x: x + width, y: y))
        path.stroke()
    }

    private func formattedDate(_ value: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: value) else { return value }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private static func dateStamp(_ value: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: value) else { return "NA" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return formatter.string(from: date)
    }
}
