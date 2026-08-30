import AVFoundation
import Foundation

// MARK: - Data Models

struct AudioInputDevice: Codable {
    let id: String
    let name: String
    let manufacturer: String
    let isDefault: Bool
}

struct EngineMetrics: Codable {
    var framesProcessed: Int
    var inputRms: Double
    var outputRms: Double
    var noiseReductionPercent: Double
    var estimatedLatencyMs: Double
    var droppedFrames: Int
    var outputQueueFrames: Int
}

struct VirtualMicrophoneState: Codable {
    var enabled: Bool
    var available: Bool
    var deviceId: String?
    var deviceName: String
    var statusMessage: String
}

struct EngineSnapshot: Codable {
    var phase: String
    var permission: String
    var selectedInputId: String?
    var systemInputId: String?
    var followSystemInput: Bool
    var inputs: [AudioInputDevice]
    var strength: Double
    var statusMessage: String
    var lastError: String?
    var metrics: EngineMetrics
    var virtualMicrophone: VirtualMicrophoneState
}

struct EngineCommand: Codable {
    let type: String
    let inputId: String?
    let strength: Double?
    let enabled: Bool?
    let requestId: String?
}

struct SnapshotEnvelope: Codable {
    let type: String
    let snapshot: EngineSnapshot
}

struct AcknowledgementEnvelope: Codable {
    let type: String
    let requestId: String
    let ok: Bool
    let error: String?
}

// MARK: - State Publisher

final class EngineStatePublisher: @unchecked Sendable {
    private let encoder = JSONEncoder()

    var snapshot = EngineSnapshot(
        phase: "booting",
        permission: "unknown",
        selectedInputId: nil,
        systemInputId: nil,
        followSystemInput: true,
        inputs: [],
        strength: 0.65,
        statusMessage: "Starting native engine",
        lastError: nil,
        metrics: EngineMetrics(
            framesProcessed: 0,
            inputRms: 0,
            outputRms: 0,
            noiseReductionPercent: 0,
            estimatedLatencyMs: 0,
            droppedFrames: 0,
            outputQueueFrames: 0
        ),
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

    func emitSnapshot() {
        do {
            let payload = try encoder.encode(
                SnapshotEnvelope(type: "snapshot", snapshot: snapshot)
            )

            if let line = String(data: payload, encoding: .utf8) {
                FileHandle.standardOutput.write(Data((line + "\n").utf8))
            }
        } catch {
            FileHandle.standardError.write(Data("Failed to encode engine snapshot\n".utf8))
        }
    }

    func emitAcknowledgement(requestId: String?, ok: Bool, error: String? = nil) {
        guard let requestId else { return }

        do {
            let payload = try encoder.encode(
                AcknowledgementEnvelope(
                    type: "ack",
                    requestId: requestId,
                    ok: ok,
                    error: error
                )
            )
            if let line = String(data: payload, encoding: .utf8) {
                FileHandle.standardOutput.write(Data((line + "\n").utf8))
            }
        } catch {
            FileHandle.standardError.write(Data("Failed to encode engine acknowledgement\n".utf8))
        }
    }
}
