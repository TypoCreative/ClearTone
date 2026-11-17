import AVFoundation
import Foundation

// MARK: - Data Models

struct AudioInputDevice: Sendable {
    let id: String
    let name: String
    let manufacturer: String
    let isDefault: Bool
}

struct EngineMetrics: Sendable {
    var framesProcessed: Int = 0
    var inputRms: Double = 0
    var outputRms: Double = 0
    var noiseReductionPercent: Double = 0
    var estimatedLatencyMs: Double = 0
    var droppedFrames: Int = 0
    var outputQueueFrames: Int = 0
}

struct VirtualMicrophoneState: Sendable {
    var enabled: Bool
    var available: Bool
    var deviceId: String?
    var deviceName: String
    var statusMessage: String
}

enum EnginePhase: String, Sendable {
    case booting, idle, starting, processing, stopping, error

    var isProcessing: Bool { self == .processing || self == .starting }
}

struct EngineSnapshot: Sendable {
    static let processingMessage = "Processing microphone input through the native engine"

    var phase: EnginePhase
    var permission: String
    var selectedInputId: String?
    var systemInputId: String?
    var followSystemInput: Bool
    var inputs: [AudioInputDevice]
    var strength: Double
    var voicePreset: VoicePreset
    var statusMessage: String
    var lastError: String?
    var metrics: EngineMetrics
    var virtualMicrophone: VirtualMicrophoneState
}

// MARK: - State Publisher

final class EngineStatePublisher: @unchecked Sendable {
    var onSnapshot: ((EngineSnapshot) -> Void)?

    var snapshot = EngineSnapshot(
        phase: .booting,
        permission: "unknown",
        selectedInputId: nil,
        systemInputId: nil,
        followSystemInput: true,
        inputs: [],
        strength: 0.65,
        voicePreset: .clear,
        statusMessage: "Starting native engine",
        lastError: nil,
        metrics: EngineMetrics(),
        virtualMicrophone: VirtualMicrophoneState(
            enabled: false,
            available: false,
            deviceId: nil,
            deviceName: VirtualMicrophoneOutput.deviceName,
            statusMessage: "Virtual microphone is off"
        )
    )

    func idleStatusMessage(currentInputName: String?) -> String {
        if snapshot.inputs.isEmpty {
            return "Waiting for a microphone device"
        }

        if snapshot.followSystemInput {
            if let current = currentInputName {
                return "Following system input: \(current)"
            }
            return "Following system input"
        }

        return currentInputName.map { "Using selected input: \($0)" } ?? "Native engine ready"
    }

    func refreshPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            snapshot.permission = "granted"
        case .denied:
            snapshot.permission = "denied"
        case .restricted:
            snapshot.permission = "restricted"
        case .notDetermined:
            snapshot.permission = "not-determined"
        @unknown default:
            snapshot.permission = "unknown"
        }
    }

    func transition(to phase: EnginePhase, message: String, error: String? = nil) {
        snapshot.phase = phase
        snapshot.statusMessage = message
        snapshot.lastError = error
        emitSnapshot()
    }

    func emitSnapshot() {
        onSnapshot?(snapshot)
    }
}
