import DeviceCheck
import CryptoKit
import Foundation
import os.log

/// Wraps Apple's DCAppAttestService for M4 (App Attest).
///
/// Flow:
///   1. First call:  generateKey → attestKey → persist keyId in UserDefaults → return attestation headers
///   2. Subsequent:  generateAssertion using persisted keyId → return assertion header
///
/// All failures are non-fatal: the caller attaches the headers **best-effort**.
/// With APP_ATTEST_MODE=off (the default) the server ignores the headers entirely.
///
/// Guard: skips automatically when running in Simulator, when DCAppAttestService.isSupported
/// is false, or when launched under -uitest.
final class AttestationService: @unchecked Sendable {

    static let shared = AttestationService()

    private let log = Logger(subsystem: "com.ecrin.jewelry", category: "attestation")

    // MARK: - Persistence

    private enum Keys {
        static let keyId = "attestation.keyId"
    }

    private var persistedKeyId: String? {
        get { UserDefaults.standard.string(forKey: Keys.keyId) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.keyId) }
    }

    private let service = DCAppAttestService.shared

    private init() {}

    // MARK: - Public API

    /// Returns headers to attach to a generation request.
    ///
    /// On first call: generates + attests the key, returns `x-attest-keyid` + `x-attest-object`.
    /// On subsequent calls: generates an assertion, returns `x-attest-keyid` + `x-attest-assertion`.
    /// Returns `[:]` if App Attest is unsupported, simulator, or -uitest.
    func attestationHeaders(clientDataHash: Data) async -> [String: String] {
        guard isAttestationAvailable() else { return [:] }

        if let keyId = persistedKeyId {
            return await assertionHeaders(keyId: keyId, clientDataHash: clientDataHash)
        } else {
            return await attestHeaders(clientDataHash: clientDataHash)
        }
    }

    // MARK: - Private

    private func isAttestationAvailable() -> Bool {
        guard !AppLaunchEnvironment.isUITesting else { return false }
        return service.isSupported
    }

    /// First-use path: generate key + attest.
    private func attestHeaders(clientDataHash: Data) async -> [String: String] {
        do {
            let keyId = try await service.generateKey()
            let attestationData = try await service.attestKey(keyId, clientDataHash: clientDataHash)
            persistedKeyId = keyId
            let attestationB64 = attestationData.base64EncodedString()
            log.info("App Attest: key attested, keyId=\(keyId, privacy: .public)")
            return [
                "x-attest-keyid": keyId,
                "x-attest-object": attestationB64,
            ]
        } catch {
            log.error("App Attest: attestation failed — \(error.localizedDescription, privacy: .public)")
            return [:]
        }
    }

    /// Subsequent-use path: generate assertion for persisted key.
    private func assertionHeaders(keyId: String, clientDataHash: Data) async -> [String: String] {
        do {
            let assertionData = try await service.generateAssertion(keyId, clientDataHash: clientDataHash)
            let assertionB64 = assertionData.base64EncodedString()
            return [
                "x-attest-keyid": keyId,
                "x-attest-assertion": assertionB64,
            ]
        } catch {
            log.error("App Attest: assertion failed — \(error.localizedDescription, privacy: .public)")
            // Key may be invalidated (factory reset, etc.) — clear persisted key so next
            // call re-attests.
            persistedKeyId = nil
            return [:]
        }
    }
}

// MARK: - Client data hash helper

extension AttestationService {

    /// Computes SHA-256 of the given JSON-serialisable request body dictionary.
    /// Used as clientDataHash for both attestation and assertion.
    static func clientDataHash(from body: [String: Any]) -> Data {
        guard let data = try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]) else {
            // Fallback: hash an empty JSON object so we never crash.
            return Data(SHA256.hash(data: Data("{}".utf8)))
        }
        return Data(SHA256.hash(data: data))
    }
}
