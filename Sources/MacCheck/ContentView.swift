import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: DiagnosticsModel
    @State private var selectedTab = "Apžvalga"
    @State private var showDisplayTest = false
    @State private var showKeyboardTest = false
    @State private var showAudioTest = false
    @State private var showMicrophoneTest = false
    @State private var showCameraTest = false
    @State private var showFanTest = false
    @State private var showSensorsTest = false
    @State private var showPowerTest = false

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
        .sheet(isPresented: $showAudioTest) { AudioChannelTestView() }
        .sheet(isPresented: $showMicrophoneTest) { MicrophoneTestView() }
        .sheet(isPresented: $showCameraTest) { CameraTestView() }
        .sheet(isPresented: $showFanTest) { FanRampTestView() }
        .sheet(isPresented: $showSensorsTest) { SensorsAndSleepTestView() }
        .sheet(isPresented: $showPowerTest) { ChargingMeterView() }
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
                ForEach(groupedTests, id: \.0) { group in
                    Section(group.0) {
                        ForEach(group.1) { test in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(test.title).font(.headline)
                                    Spacer()
                                    if test.id == "display" {
                                        Button("Atverti testą") { showDisplayTest = true }
                                    } else if test.id == "keyboard" {
                                        Button("Atverti testą") { showKeyboardTest = true }
                                    } else if test.id == "speakers" {
                                        Button("Tikrinti kanalus") { showAudioTest = true }
                                    } else if test.id == "microphone" {
                                        Button("Įrašyti ir paleisti") { showMicrophoneTest = true }
                                    } else if test.id == "camera" {
                                        Button("Paleisti kamerą") { showCameraTest = true }
                                    } else if test.id == "thermal" {
                                        Button("Tikrinti ventiliatorių") { showFanTest = true }
                                    } else if test.id == "sensors" || test.id == "sleep" {
                                        Button("Atverti testą") { showSensorsTest = true }
                                    } else if test.id == "charging" {
                                        Button("Rodyti V / A / W") { showPowerTest = true }
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
    private let colors: [(String, Color)] = [
        ("Balta", .white), ("Juoda", .black), ("Raudona", .red),
        ("Žalia", .green), ("Mėlyna", .blue), ("Geltona", .yellow),
        ("Žydra", .cyan), ("Purpurinė", .purple), ("Pilka", .gray)
    ]
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
                    Text("Ieškok dėmių, linijų, mirgėjimo ar neveikiančių pikselių").padding(10).background(.ultraThinMaterial).clipShape(.capsule)
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
    @StateObject private var listener = KeyboardEventListener()
    private let keys = KeyboardEventListener.visibleKeys
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 14)
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
            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(keys.indices, id: \.self) { index in
                    let key = keys[index]
                    Text(key).font(.system(size: 11, weight: .medium, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(pressed.contains(key) ? Color.green.opacity(0.75) : Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            Text("Spausk klavišus, kol šis langas atvertas — atskiro įvesties laukelio aktyvuoti nereikia. Touch ID ir kai kuriuos medijos klavišus tikrink atskirai.")
                .font(.callout).foregroundStyle(.secondary)
            Button("Išvalyti pažymėjimus") { pressed.removeAll() }
            Spacer(minLength: 0)
        }
        .padding(24).frame(minWidth: 760, minHeight: 560)
        .onAppear { listener.start { pressed.insert($0) } }
        .onDisappear { listener.stop() }
    }
}

@MainActor
private final class KeyboardEventListener: ObservableObject {
    static let visibleKeys = [
        "ESC", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=", "DELETE",
        "TAB", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]", "\\",
        "CAPS", "A", "S", "D", "F", "G", "H", "J", "K", "L", ";", "'", "RETURN", "",
        "L SHIFT", "Z", "X", "C", "V", "B", "N", "M", ",", ".", "/", "↑", "R SHIFT",
        "FN", "L CONTROL", "L OPTION", "L COMMAND", "SPACE", "R COMMAND", "R OPTION", "R CONTROL", "←", "↓", "→",
        "FORWARD DELETE", "HOME", "END", "PAGE UP", "PAGE DOWN"
    ]

    private var monitor: Any?
    private var onKey: ((String) -> Void)?

    func start(onKey: @escaping (String) -> Void) {
        stop()
        self.onKey = onKey
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self, event.window === NSApp.keyWindow else { return event }
            self.handle(event)
            return event
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        onKey = nil
    }

    private func handle(_ event: NSEvent) {
        if event.type == .flagsChanged {
            let modifiers: [UInt16: String] = [
                54: "R COMMAND", 55: "L COMMAND", 56: "L SHIFT", 60: "R SHIFT",
                57: "CAPS", 58: "L OPTION", 61: "R OPTION", 59: "L CONTROL", 62: "R CONTROL", 63: "FN"
            ]
            if let key = modifiers[event.keyCode] { onKey?(key) }
            return
        }

        let physical: [UInt16: String] = [
            53:"ESC", 122:"F1", 120:"F2", 99:"F3", 118:"F4", 96:"F5", 97:"F6", 98:"F7", 100:"F8", 101:"F9", 109:"F10", 103:"F11", 111:"F12",
            18:"1", 19:"2", 20:"3", 21:"4", 23:"5", 22:"6", 26:"7", 28:"8", 25:"9", 29:"0", 27:"-", 24:"=", 51:"DELETE",
            48:"TAB", 12:"Q", 13:"W", 14:"E", 15:"R", 17:"T", 16:"Y", 32:"U", 34:"I", 31:"O", 35:"P", 33:"[", 30:"]", 42:"\\",
            57:"CAPS", 0:"A", 1:"S", 2:"D", 3:"F", 5:"G", 4:"H", 38:"J", 40:"K", 37:"L", 41:";", 39:"'", 36:"RETURN",
            56:"L SHIFT", 6:"Z", 7:"X", 8:"C", 9:"V", 11:"B", 45:"N", 46:"M", 43:",", 47:".", 44:"/", 60:"R SHIFT",
            63:"FN", 59:"L CONTROL", 58:"L OPTION", 55:"L COMMAND", 49:"SPACE", 62:"R CONTROL", 61:"R OPTION", 54:"R COMMAND",
            123:"←", 124:"→", 125:"↓", 126:"↑", 117:"FORWARD DELETE", 115:"HOME", 119:"END", 116:"PAGE UP", 121:"PAGE DOWN"
        ]
        if let key = physical[event.keyCode] { onKey?(key); return }
        if let character = event.charactersIgnoringModifiers?.uppercased(), !character.isEmpty {
            onKey?(character)
        }
    }
}
