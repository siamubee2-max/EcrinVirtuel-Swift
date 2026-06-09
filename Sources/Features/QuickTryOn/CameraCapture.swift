import SwiftUI
import UIKit
import AVFoundation

// MARK: - CameraCapture
// Wrapper SwiftUI sur UIImagePickerController pour prendre une photo.
// Ne fonctionne PAS dans le simulateur (pas de caméra hardware).
// Sur device réel : utilise NSCameraUsageDescription d'Info.plist.

struct CameraCapture: UIViewControllerRepresentable {

    let onCapture: (UIImage) -> Void
    let onCancel:  () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        // Si caméra indisponible (sim), fallback sur photothèque
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.allowsEditing = false
        picker.cameraDevice = .front  // Caméra avant par défaut (essayage = selfie)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraCapture
        init(_ parent: CameraCapture) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            } else {
                parent.onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}

// MARK: - CameraAvailability helper

enum CameraAvailability {
    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    /// Demande l'autorisation caméra. Retourne `true` si accordée.
    static func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:                  return true
        case .denied, .restricted:         return false
        case .notDetermined:               return await AVCaptureDevice.requestAccess(for: .video)
        @unknown default:                  return false
        }
    }
}
