import SwiftUI
import AppKit
import Combine
import IOKit
import IOKit.ps

struct ChargingMeterView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var monitor = ChargingPowerMonitor()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Įkrovimo matuoklis").font(.title.bold())
                Spacer()
                Button("Uždaryti") { dismiss() }.keyboardShortcut(.escape)
            }
            Text("Rodoma baterijos pusės telemetrija. Tai nėra USB‑C adapterio išėjimo matavimas.")
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                readingCard("Įtampa", value: monitor.reading.voltage.map { format($0, digits: 2) + " V" } ?? "—")
                readingCard("Srovė", value: monitor.reading.current.map { format($0, digits: 3) + " A" } ?? "—")
                readingCard("Galia", value: monitor.reading.watts.map { format($0, digits: 2) + " W" } ?? "—")
            }
            GroupBox("Baterijos būsena") {
                VStack(alignment: .leading, spacing: 8) {
                    Label(monitor.reading.state, systemImage: monitor.reading.isCharging ? "bolt.fill" : "battery.100")
                    if let percent = monitor.reading.percent { Text("Įkrova: \(percent)%") }
                    if let updated = monitor.reading.updatedAt {
                        Text("Atnaujinta: \(updated.formatted(date: .omitted, time: .standard))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
            }
            Label(monitor.reading.details, systemImage: "info.circle")
                .font(.callout).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(24)
        .frame(minWidth: 650, minHeight: 300)
        .onAppear { monitor.refresh() }
        .onReceive(timer) { _ in monitor.refresh() }
    }

    private func readingCard(_ title: String, value: String) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 5) {
                Text(value).font(.title2.bold()).monospacedDigit()
                Text(title).font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
        }
    }

    private func format(_ value: Double, digits: Int) -> String {
        String(format: "%.*f", digits, value)
    }
}

private struct ChargeReading {
    var voltage: Double? = nil
    var current: Double? = nil
    var watts: Double? = nil
    var percent: Int? = nil
    var isCharging = false
    var state = "Nuskaitomi baterijos duomenys…"
    var details = "V/A/W skaičiuojami pagal baterijos įtampą ir srovę, ne adapterio išėjimą."
    var updatedAt: Date? = nil
}

@MainActor
private final class ChargingPowerMonitor: ObservableObject {
    @Published private(set) var reading = ChargeReading()

    func refresh() {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        guard let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as? [CFTypeRef] else {
            reading = ChargeReading(state: "macOS baterijos duomenų nepateikė.")
            return
        }

        for source in sources {
            guard let raw = IOPSGetPowerSourceDescription(info, source).takeUnretainedValue() as? [String: Any],
                  (raw[kIOPSTypeKey as String] as? String) == (kIOPSInternalBatteryType as String) else { continue }

            let registry = readSmartBatteryProperties()
            let millivolts = (raw[kIOPSVoltageKey as String] as? NSNumber)?.doubleValue
                ?? number(registry["Voltage"])
            let milliamps = (raw[kIOPSCurrentKey as String] as? NSNumber)?.doubleValue
                ?? number(registry["InstantAmperage"])
                ?? number(registry["Amperage"])
            let voltage = millivolts.map { $0 / 1000 }
            let current = milliamps.map { abs($0) / 1000 }
            let isCharging = (raw[kIOPSIsChargingKey as String] as? NSNumber)?.boolValue
                ?? (registry["IsCharging"] as? NSNumber)?.boolValue
                ?? false
            let pluggedIn = (raw[kIOPSPowerSourceStateKey as String] as? String) == (kIOPSACPowerValue as String)
            let level = (raw[kIOPSCurrentCapacityKey as String] as? NSNumber)?.intValue
            let state = isCharging ? "Į bateriją teka įkrovimo srovė" : (pluggedIn ? "Maitinimas prijungtas; baterija šiuo metu nekraunama" : "Kompiuteris veikia iš baterijos")
            var missing: [String] = []
            if voltage == nil { missing.append("įtampos") }
            if current == nil { missing.append("srovės") }
            let details = missing.isEmpty
                ? "Rodoma baterijos pusės telemetrija, ne USB‑C adapterio išėjimo matavimas. Pilnai įkrautoje baterijoje srovė gali būti artima nuliui."
                : "Šis Mac pateikė baterijos įkrovos procentą, bet nepateikė \(missing.joined(separator: " ir ")). Todėl jų reikšmių patikimai apskaičiuoti negalima."
            reading = ChargeReading(
                voltage: voltage,
                current: current,
                watts: voltage.flatMap { v in current.map { v * $0 } },
                percent: level,
                isCharging: isCharging,
                state: state,
                details: details,
                updatedAt: Date()
            )
            return
        }

        reading = ChargeReading(state: "Vidinės baterijos duomenų nerasta. Tai gali būti stacionarus Mac arba nepalaikomas maitinimo šaltinis.")
    }

    private func number(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }

    private func readSmartBatteryProperties() -> [String: Any] {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return [:] }
        defer { IOObjectRelease(service) }

        var unmanagedProperties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(service, &unmanagedProperties, kCFAllocatorDefault, 0)
        guard result == KERN_SUCCESS,
              let properties = unmanagedProperties?.takeRetainedValue() as? [String: Any] else { return [:] }
        return properties
    }
}

struct SensorsAndSleepTestView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var sleepMonitor = SleepWakeMonitor()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Jutiklių ir miego testas").font(.title.bold())
                Spacer()
                Button("Uždaryti") { dismiss() }.keyboardShortcut(.escape)
            }
            GroupBox("Dangčio kampas / akcelerometras") {
                VStack(alignment: .leading, spacing: 7) {
                    Label("Tikslaus kampo reikšmės macOS nepateikia", systemImage: "rotate.3d")
                        .font(.headline)
                    Text("MacBook modeliai neturi vienodo viešo kampo jutiklio API. Programa nerodys išgalvotų laipsnių; patikrinamas dangčio uždarymo sukeltas miego režimas.")
                        .font(.callout).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
            }
            GroupBox("Aplinkos šviesumo jutiklis") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tiesioginio lux rodmens macOS vieša sąsaja patikimai neteikia. Funkcinį bandymą atlik su įjungtu automatiniu ekrano šviesumu:")
                        .font(.callout).foregroundStyle(.secondary)
                    Label("Sistemos nustatymai → Ekranai → įjunk automatinį šviesumo reguliavimą.", systemImage: "sun.max")
                    Text("Uždenk ir atidenk jutiklio langelį šalia kameros (jo vieta priklauso nuo modelio) ir stebėk, ar keičiasi ekrano šviesumas. Pakeitimui gali reikėti kelių sekundžių.")
                        .font(.callout)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
            }
            GroupBox("Dangčio uždarymas ir kompiuterio miegas") {
                VStack(alignment: .leading, spacing: 8) {
                    Label(sleepMonitor.message, systemImage: sleepMonitor.didWake ? "sun.max.fill" : "moon.zzz")
                        .font(.headline)
                    Text("Palik šį langą atvertą, užverk MacBook dangtį 10 sekundžių, tada atverk. MacCheck užfiksuos miego ir pabudimo pranešimus po to, kai sistema vėl pradės veikti.")
                        .font(.callout).foregroundStyle(.secondary)
                    if let time = sleepMonitor.lastEvent {
                        Text("Paskutinis įvykis: \(time.formatted(date: .abbreviated, time: .standard))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
            }
            Spacer()
        }
        .padding(24)
        .frame(minWidth: 680, minHeight: 560)
        .onAppear { sleepMonitor.start() }
        .onDisappear { sleepMonitor.stop() }
    }
}

@MainActor
private final class SleepWakeMonitor: ObservableObject {
    @Published private(set) var message = "Laukiama dangčio uždarymo arba miego režimo…"
    @Published private(set) var didWake = false
    @Published private(set) var lastEvent: Date?
    private var tokens: [NSObjectProtocol] = []

    func start() {
        guard tokens.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        tokens.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.message = "macOS siunčia miego režimo pranešimą. Atverk dangtį, kad patikrintum pabudimą."
                self?.didWake = false
                self?.lastEvent = Date()
            }
        })
        tokens.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.message = "Mac pabudo iš miego režimo. Dangčio / miego testas užfiksuotas."
                self?.didWake = true
                self?.lastEvent = Date()
            }
        })
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter
        tokens.forEach(center.removeObserver)
        tokens.removeAll()
    }
}
