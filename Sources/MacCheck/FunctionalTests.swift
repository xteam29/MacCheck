import SwiftUI
import AVFoundation
import AppKit
import Combine

enum StereoSide: String, CaseIterable, Identifiable {
    case left = "Kairysis kanalas"
    case right = "Dešinysis kanalas"
    case both = "Abu kanalai"

    var id: String { rawValue }
}

@MainActor
final class StereoTonePlayer: ObservableObject {
    @Published private(set) var playing = false
    @Published var error: String?
    private var engine: AVAudioEngine?
    private var node: AVAudioPlayerNode?

    func play(_ side: StereoSide) {
        stop()
        error = nil
        do {
            let rate = 44_100.0
            guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2),
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44_100),
                  let channels = buffer.floatChannelData else {
                error = "Nepavyko paruošti garso testo."
                return
            }
            buffer.frameLength = 44_100
            for frame in 0..<Int(buffer.frameLength) {
                let t = Double(frame) / rate
                let fade = min(1.0, min(Double(frame) / 500.0, Double(44_100 - frame) / 500.0))
                let sample = Float(sin(2 * Double.pi * 440 * t) * 0.16 * max(0, fade))
                channels[0][frame] = side == .right ? 0 : sample
                channels[1][frame] = side == .left ? 0 : sample
            }

            let audioEngine = AVAudioEngine()
            let player = AVAudioPlayerNode()
            audioEngine.attach(player)
            audioEngine.connect(player, to: audioEngine.mainMixerNode, format: format)
            try audioEngine.start()
            self.engine = audioEngine
            self.node = player
            playing = true
            player.scheduleBuffer(buffer) { [weak self] in
                Task { @MainActor in self?.stop() }
            }
            player.play()
        } catch {
            self.error = "Nepavyko paleisti garso: \(error.localizedDescription)"
            stop()
        }
    }

    func stop() {
        node?.stop()
        engine?.stop()
        node = nil
        engine = nil
        playing = false
    }
}

struct AudioChannelTestView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var player = StereoTonePlayer()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Garsiakalbių kanalų testas").font(.title.bold())
                Spacer()
                Button("Uždaryti") { player.stop(); dismiss() }.keyboardShortcut(.escape)
            }
            Text("Pradėk nuo mažo garsumo. Kiekvienas mygtukas leidžia trumpą toną pasirinktu kanalu.")
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                ForEach(StereoSide.allCases) { side in
                    Button(side.rawValue) { player.play(side) }
                        .buttonStyle(.borderedProminent)
                        .disabled(player.playing)
                }
                if player.playing { Button("Sustabdyti") { player.stop() } }
            }
            if let error = player.error { Text(error).foregroundStyle(.red) }
            Label("Pasirink macOS garso išvestį, kurią nori tikrinti (vidiniai garsiakalbiai arba ausinės).", systemImage: "speaker.wave.2")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(24)
        .frame(minWidth: 560, minHeight: 280)
        .onDisappear { player.stop() }
    }
}

@MainActor
final class MicrophoneRecorder: ObservableObject {
    @Published private(set) var recording = false
    @Published private(set) var hasRecording = false
    @Published private(set) var playing = false
    @Published var message = "Paspausk „Pradėti įrašą“ ir pasakyk kelis žodžius."
    private var recorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var fileURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("MacCheck-mikrofono-testas.m4a")
    }

    func startRecording() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            beginRecording()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted { self.beginRecording() }
                    else { self.message = "Mikrofono leidimas nesuteiktas. Įjunk jį Sistemos nustatymuose → Privatumas ir sauga → Mikrofonas." }
                }
            }
        case .denied, .restricted:
            message = "Mikrofono leidimas uždraustas. Įjunk jį Sistemos nustatymuose → Privatumas ir sauga → Mikrofonas."
        @unknown default:
            message = "Nepavyko patikrinti mikrofono leidimo."
        }
    }

    private func beginRecording() {
        do {
            try? FileManager.default.removeItem(at: fileURL)
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let newRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            newRecorder.prepareToRecord()
            guard newRecorder.record() else {
                message = "Įrašymo pradėti nepavyko. Patikrink mikrofono leidimą ir įvesties įrenginį."
                return
            }
            recorder = newRecorder
            recording = true
            hasRecording = false
            message = "Įrašoma… Pasakyk kelis žodžius, tada spausk „Baigti įrašą“."
        } catch {
            message = "Mikrofono klaida: \(error.localizedDescription)"
        }
    }

    func stopRecording() {
        recorder?.stop()
        recorder = nil
        recording = false
        hasRecording = FileManager.default.fileExists(atPath: fileURL.path)
        message = hasRecording ? "Įrašas paruoštas. Paleisk jį ir patikrink, ar girdisi aiškiai." : "Įrašo nepavyko išsaugoti."
    }

    func playRecording() {
        guard hasRecording else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: fileURL)
            player.prepareToPlay()
            player.play()
            audioPlayer = player
            playing = true
            message = "Atkuriamas mikrofono įrašas."
            DispatchQueue.main.asyncAfter(deadline: .now() + player.duration) { [weak self] in
                self?.playing = false
                self?.message = "Atkūrimas baigtas. Ar įrašas girdėjosi aiškiai?"
            }
        } catch {
            message = "Nepavyko paleisti įrašo: \(error.localizedDescription)"
        }
    }

    func stop() {
        if recording { stopRecording() }
        audioPlayer?.stop()
        audioPlayer = nil
        playing = false
    }
}

struct MicrophoneTestView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = MicrophoneRecorder()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Mikrofono testas").font(.title.bold())
                Spacer()
                Button("Uždaryti") { recorder.stop(); dismiss() }.keyboardShortcut(.escape)
            }
            Label(recorder.message, systemImage: recorder.recording ? "waveform" : "mic")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding().background(.quaternary).clipShape(RoundedRectangle(cornerRadius: 10))
            HStack {
                if recorder.recording {
                    Button("Baigti įrašą") { recorder.stopRecording() }.buttonStyle(.borderedProminent)
                } else {
                    Button("Pradėti įrašą") { recorder.startRecording() }.buttonStyle(.borderedProminent)
                }
                Button("Paleisti įrašą") { recorder.playRecording() }
                    .disabled(!recorder.hasRecording || recorder.recording || recorder.playing)
                if recorder.playing { Button("Sustabdyti") { recorder.stop() } }
            }
            Text("Įrašas laikomas laikiname aplanke ir pašalinamas, kai uždaroma programa.")
                .font(.callout).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(24)
        .frame(minWidth: 580, minHeight: 300)
        .onDisappear { recorder.stop() }
    }
}

@MainActor
final class CameraSession: ObservableObject {
    @Published private(set) var running = false
    @Published var message = "Kamera išjungta."
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "MacCheck.CameraSession")
    private var configured = false

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: configureAndStart()
        case .notDetermined:
            message = "Laukiama leidimo naudoti kamerą…"
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted { self.configureAndStart() }
                    else { self.message = "Kameros leidimas nesuteiktas. Įjunk jį Sistemos nustatymuose → Privatumas ir sauga → Kamera." }
                }
            }
        case .denied, .restricted:
            message = "Kameros leidimas uždraustas. Įjunk jį Sistemos nustatymuose → Privatumas ir sauga → Kamera."
        @unknown default:
            message = "Nepavyko patikrinti kameros leidimo."
        }
    }

    private func configureAndStart() {
        message = "Paleidžiama kamera…"
        queue.async { [weak self] in
            guard let self else { return }
            if !self.configured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .high
                if let device = AVCaptureDevice.default(for: .video),
                   let input = try? AVCaptureDeviceInput(device: device),
                   self.session.canAddInput(input) {
                    self.session.addInput(input)
                    self.configured = true
                }
                self.session.commitConfiguration()
            }
            guard self.configured else {
                DispatchQueue.main.async { self.message = "Kamera nerasta arba jos nepavyko paleisti." }
                return
            }
            if !self.session.isRunning { self.session.startRunning() }
            DispatchQueue.main.async {
                self.running = self.session.isRunning
                self.message = self.running ? "Kamera veikia. Patikrink vaizdą ir fokusavimą." : "Kameros paleisti nepavyko."
            }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.running = false
                self.message = "Kamera išjungta."
            }
        }
    }
}

struct CameraTestView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraSession()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Kameros testas").font(.title.bold())
                Spacer()
                Button("Uždaryti") { camera.stop(); dismiss() }.keyboardShortcut(.escape)
            }
            Text(camera.message).foregroundStyle(.secondary)
            CameraPreview(session: camera.session)
                .frame(minWidth: 600, minHeight: 360)
                .background(.black)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            HStack {
                Button(camera.running ? "Paleisti iš naujo" : "Paleisti kamerą") {
                    camera.stop()
                    camera.start()
                }.buttonStyle(.borderedProminent)
                if camera.running { Button("Išjungti kamerą") { camera.stop() } }
            }
        }
        .padding(20)
        .frame(minWidth: 660, minHeight: 500)
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
    }
}

private struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession
    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView()
        view.previewLayer.session = session
        return view
    }
    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {
        nsView.previewLayer.session = session
    }
}

private final class CameraPreviewNSView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        previewLayer.videoGravity = .resizeAspect
        layer = previewLayer
    }
    required init?(coder: NSCoder) { nil }
    override func layout() {
        super.layout()
        previewLayer.frame = bounds
    }
}

private final class FanStressGate: @unchecked Sendable {
    private let lock = NSLock()
    private var stopped = false
    func stop() { lock.lock(); stopped = true; lock.unlock() }
    var shouldStop: Bool { lock.lock(); defer { lock.unlock() }; return stopped }
}

@MainActor
final class FanRampTest: ObservableObject {
    @Published private(set) var running = false
    @Published private(set) var remaining = 0
    @Published var message = "macOS pati valdo ventiliatorių apsukas."
    private var gate: FanStressGate?

    func start() {
        guard !running else { return }
        let gate = FanStressGate()
        self.gate = gate
        running = true
        remaining = 15
        message = "Vyksta trumpas apkrovos bandymas. Klausykis, ar ventiliatorius pradeda suktis greičiau."
        let deadline = Date().addingTimeInterval(15)
        let workers = max(1, ProcessInfo.processInfo.activeProcessorCount)
        for _ in 0..<workers {
            DispatchQueue.global(qos: .userInitiated).async {
                var value = 0.0
                while Date() < deadline && !gate.shouldStop {
                    for index in 1...2_000 { value += sqrt(Double(index)) }
                    if value > 1_000_000 { value = 0 }
                }
            }
        }
        Task { @MainActor in
            for second in stride(from: 14, through: 0, by: -1) {
                try? await Task.sleep(for: .seconds(1))
                guard running else { return }
                remaining = second
            }
            stop()
        }
    }

    func stop() {
        gate?.stop()
        gate = nil
        running = false
        remaining = 0
        message = "Bandymas baigtas. Ventiliatorius toliau valdomas macOS."
    }
}

struct FanRampTestView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var test = FanRampTest()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Ventiliatoriaus reakcijos testas").font(.title.bold())
                Spacer()
                Button("Uždaryti") { test.stop(); dismiss() }.keyboardShortcut(.escape)
            }
            Label(test.message, systemImage: "fan")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding().background(.quaternary).clipShape(RoundedRectangle(cornerRadius: 10))
            if test.running {
                ProgressView(value: Double(15 - test.remaining), total: 15)
                Text("Liko \(test.remaining) s")
                Button("Sustabdyti dabar") { test.stop() }.buttonStyle(.borderedProminent)
            } else {
                Button("Pradėti 15 s testą") { test.start() }.buttonStyle(.borderedProminent)
            }
            Text("Programa negali saugiai priverstinai nustatyti maksimalių RPM. Šis trumpas apkrovos bandymas leidžia macOS pačiai padidinti ventiliatoriaus greitį. Jis negarantuoja maksimalių apsukų ar RPM matavimo. Jei kompiuteris jau labai įkaitęs, testo nepradėk.")
                .font(.callout).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(24)
        .frame(minWidth: 600, minHeight: 340)
        .onDisappear { test.stop() }
    }
}
