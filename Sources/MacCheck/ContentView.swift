import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: DiagnosticsModel
    @State private var selectedTab = "Apžvalga"
    @State private var showDisplayTest = false
    @State private var showKeyboardTest = false

    private let tabs = ["Apžvalga", "Įrenginiai", "Rankiniai testai"]

    var body: some View {
        NavigationSplitView {
            List(tabs, id: \.self, selection: $selectedTab) { tab in
                Label(tab, systemImage: icon(for: tab)).tag(tab)
            }
            .navigationTitle("MacCheck")
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("MacBook diagnostika").font(.caption).foregroundStyle(.secondary)
                    Text("Informacinis įrankis").font(.caption2).foregroundStyle(.tertiary)
                }.padding()
            }
        } detail: {
            Group {
                switch selectedTab {
                case "Įrenginiai": inventoryView
                case "Rankiniai testai": testsView
                default: overviewView
                }
            }
            .toolbar {
                ToolbarItemGroup {
                    Button { model.runScan() } label: {
                        if model.isScanning { ProgressView().controlSize(.small) }
                        else { Label("Nuskaityti", systemImage: "arrow.clockwise") }
                    }.disabled(model.isScanning)
                    Menu {
                        Button { model.exportPDF() } label: { Label("Išsaugoti PDF", systemImage: "doc.richtext") }
                        Button { model.printReport() } label: { Label("Spausdinti ataskaitą", systemImage: "printer") }
                        Divider()
                        Button { model.exportReport() } label: { Label("Eksportuoti JSON", systemImage: "curlybraces") }
                    } label: {
                        Label("Ataskaita", systemImage: "square.and.arrow.up")
                    }
                    .disabled(model.isScanning)
                }
            }
        }
        .task { if model.inventory.isEmpty { model.runScan() } }
        .sheet(isPresented: $showDisplayTest) { DisplayColorTest() }
        .sheet(isPresented: $showKeyboardTest) { KeyboardTestView() }
        .alert("Ataskaitos klaida", isPresented: Binding(
            get: { model.reportError != nil },
            set: { if !$0 { model.reportError = nil } }
        )) {
            Button("Gerai", role: .cancel) { model.reportError = nil }
        } message: {
            Text(model.reportError ?? "")
        }
    }

    private var overviewView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("MacBook patikra").font(.largeTitle.bold())
                    Text("Užfiksuok automatinio nuskaitymo duomenis ir atlik fizinius testus prieš grąžindamas įrenginį.")
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    MetricCard(title: "Veikia", value: "\(model.passedCount)", symbol: "checkmark.circle.fill", color: .green)
                    MetricCard(title: "Gedimai", value: "\(model.failedCount)", symbol: "xmark.circle.fill", color: .red)
                    MetricCard(title: "Liko", value: "\(model.remainingCount)", symbol: "circle.dashed", color: .secondary)
                }
                GroupBox("Automatinis nuskaitymas") {
                    VStack(alignment: .leading, spacing: 10) {
                        if let date = model.lastScan {
                            Label("Atlikta \(date.formatted(date: .abbreviated, time: .shortened))", systemImage: "checkmark.circle")
                            Text("Nuskaitymas pateikia macOS matomą įrenginių informaciją. Jis pats nepatvirtina, kad komponentas veikia tinkamai.")
                                .font(.callout).foregroundStyle(.secondary)
                            Text("Rasta \(model.inventory.count) informacijos įrašų.").font(.callout)
                        } else { ProgressView("Nuskaitoma įrenginio informacija…") }
                        if let error = model.scanError { Text(error).font(.callout).foregroundStyle(.orange) }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 5)
                }
                HStack {
                    Button { selectedTab = "Rankiniai testai" } label: { Label("Pradėti rankinius testus", systemImage: "checklist") }
                        .buttonStyle(.borderedProminent)
                    Button { showDisplayTest = true } label: { Label("Ekrano testas", systemImage: "display") }
                    Button { showKeyboardTest = true } label: { Label("Klaviatūros testas", systemImage: "keyboard") }
                }
                GroupBox("Svarbu") {
                    Text("Rezultatus įvertina darbuotojas. Jei reikia patikrinti atminties, saugyklos, jutiklių ar maitinimo grandinių gedimus, papildomai naudok Apple Diagnostics ir gamintojo remonto procedūras.")
                        .frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(.secondary).padding(.vertical, 4)
                }
            }.padding(24)
        }
    }

    private var inventoryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Įrenginių informacija").font(.largeTitle.bold())
            Text("Duomenys nuskaitomi iš macOS sistemos ataskaitų. Jie rodo aptikimą, ne funkcinio testo rezultatą.")
                .foregroundStyle(.secondary)
            if model.inventory.isEmpty {
                VStack(spacing: 8) {
                    Label("Duomenų nėra", systemImage: "info.circle")
                        .font(.headline)
                    Text("Paspausk „Nuskaityti“.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            else {
                List(model.inventory) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.name).font(.headline)
                            Spacer()
                            Text(item.result).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(item.detail).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    }.padding(.vertical, 4)
                }.listStyle(.inset)
            }
            Spacer()
        }.padding(24)
    }

    private var testsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rankiniai testai").font(.largeTitle.bold())
            Text("Atlik veiksmą su žinomu veikiančiu priedu, tada pažymėk rezultatą.").foregroundStyle(.secondary)
            List {
                ForEach(groupedTests, id: \.0) { group, tests in
                    Section(group) {
                        ForEach(tests) { test in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(test.title).font(.headline)
                                    Spacer()
                                    if test.id == "display" {
                                        Button("Atverti testą") { showDisplayTest = true }
                                    } else if test.id == "keyboard" {
                                        Button("Atverti testą") { showKeyboardTest = true }
                                    }
                                    Picker("Rezultatas", selection: statusBinding(for: test)) {
                                        ForEach(TestStatus.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                                    }.labelsHidden().frame(width: 135)
                                }
                                Text(test.instructions).font(.callout).foregroundStyle(.secondary)
                            }.padding(.vertical, 5)
                        }
                    }
                }
            }.listStyle(.inset)
        }.padding(24)
    }

    private var groupedTests: [(String, [ManualTest])] {
        let groups = Dictionary(grouping: model.tests, by: \.category)
        return groups.keys.sorted().map { ($0, groups[$0] ?? []) }
    }

    private func statusBinding(for test: ManualTest) -> Binding<TestStatus> {
        Binding(get: { model.tests.first(where: { $0.id == test.id })?.status ?? .notRun },
                set: { model.setStatus($0, for: test.id) })
    }

    private func icon(for tab: String) -> String {
        switch tab { case "Įrenginiai": "desktopcomputer"; case "Rankiniai testai": "checklist"; default: "gauge.with.dots.needle.67percent" }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let symbol: String
    let color: Color
    var body: some View {
        GroupBox {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.title2).foregroundStyle(color)
                VStack(alignment: .leading) { Text(value).font(.title2.bold()); Text(title).font(.caption).foregroundStyle(.secondary) }
                Spacer(minLength: 0)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
        }
    }
}

private struct DisplayColorTest: View {
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    private let colors: [(String, Color)] = [("Balta", .white), ("Juoda", .black), ("Raudona", .red), ("Žalia", .green), ("Mėlyna", .blue), ("Pilka", .gray)]
    var body: some View {
        ZStack {
            colors[index].1.ignoresSafeArea()
            VStack {
                HStack {
                    Text("Ekrano testas · \(colors[index].0)").padding(10).background(.ultraThinMaterial).clipShape(.capsule)
                    Spacer()
                    Button("Baigti") { dismiss() }.keyboardShortcut(.escape).padding(10).background(.ultraThinMaterial).clipShape(.capsule)
                }
                Spacer()
                HStack {
                    Button("← Ankstesnė") { index = (index - 1 + colors.count) % colors.count }
                    Spacer()
                    Text("Patikrink dėmes, linijas ir mirgėjimą").padding(10).background(.ultraThinMaterial).clipShape(.capsule)
                    Spacer()
                    Button("Kita →") { index = (index + 1) % colors.count }
                }
            }.padding(18)
        }.frame(minWidth: 700, minHeight: 450)
    }
}

private struct KeyboardTestView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pressed: Set<String> = []
    private let keys = "1234567890QWERTYUIOPASDFGHJKLZXCVBNM".map(String.init)
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 10)
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Klaviatūros testas").font(.title.bold())
                    Text("Paspausti klavišai pažymimi tik šio lango atmintyje.").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Uždaryti") { dismiss() }.keyboardShortcut(.escape)
            }
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(keys, id: \.self) { key in
                    Text(key).frame(maxWidth: .infinity, minHeight: 34)
                        .background(pressed.contains(key) ? Color.green.opacity(0.75) : Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            HStack {
                ForEach(["Tab", "Caps", "Shift", "Control", "Option", "Command", "Space", "Return", "Delete", "←", "↑", "↓", "→"], id: \.self) { key in
                    Text(key).font(.caption2).padding(7)
                        .background(pressed.contains(key.uppercased()) ? Color.green.opacity(0.75) : Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
            }
            Text("Spustelėk žemiau ir bandyk klavišus. Touch ID ir Fn patikrinki atskirai.").font(.callout).foregroundStyle(.secondary)
            KeyCaptureView { key in
                if let key, keys.contains(key) { pressed.insert(key) }
                else if let key { pressed.insert(key.uppercased()) }
            }.frame(height: 46).background(Color.accentColor.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(Text("Spustelėk šią sritį, kad aktyvuotum testą").foregroundStyle(.secondary).allowsHitTesting(false))
            Button("Išvalyti pažymėjimus") { pressed.removeAll() }
            Spacer(minLength: 0)
        }.padding(24).frame(minWidth: 720, minHeight: 500)
    }
}

private struct KeyCaptureView: NSViewRepresentable {
    var onKey: (String?) -> Void
    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onKey = onKey
        return view
    }
    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) { nsView.onKey = onKey }
}

private final class KeyCaptureNSView: NSView {
    var onKey: ((String?) -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self) }
    override func keyDown(with event: NSEvent) {
        let key = event.charactersIgnoringModifiers?.uppercased()
        onKey?(key)
    }
}
