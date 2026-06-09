// FirstRunFlowView.swift — Coordonne wizard → génération IA → écran résultat
// Path: Sources/Features/QuickTryOn/FirstRunFlowView.swift

import SwiftUI

struct FirstRunFlowView: View {
    @Environment(AppState.self) private var appState

    let onFinish: () -> Void

    @State private var viewModel = TryOnViewModel()
    @State private var showResult = false
    @State private var showPaywall = false
    @State private var showGenerationAuth = false
    @State private var lastJewelryName = ""
    @State private var pendingPhoto: UIImage?
    @State private var pendingJewelry: JewelryItem?
    @State private var authContinuation: CheckedContinuation<Bool, Never>? = nil

    var body: some View {
        Group {
            if showResult, let image = viewModel.result?.first {
                QuickTryOnResultView(
                    image: image,
                    modeName: lastJewelryName,
                    onRetry: {
                        showResult = false
                        viewModel.result = nil
                    },
                    onClose: finishFlow,
                    onNextJewelry: CreditsManager.shared.remaining > 0 ? { showResult = false } : nil,
                    creditsRemaining: CreditsManager.shared.remaining,
                    nudgePicks: WizardConfig.nudgePicks,
                    onSelectNudgeJewelry: { _ in
                        showResult = false
                        viewModel.result = nil
                    }
                )
            } else {
                FirstRunWizardView { photo, jewelry in
                    lastJewelryName = jewelry.name
                    viewModel.userPhoto = photo
                    viewModel.selectedJewelry = jewelry
                    pendingPhoto = photo
                    pendingJewelry = jewelry
                    if await GenerationAuthGate.hasSession() {
                        return await runFirstRunGeneration()
                    }
                    
                    return await withCheckedContinuation { continuation in
                        authContinuation = continuation
                        showGenerationAuth = true
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            EmotionalPaywallView(generatedImages: SessionCreationsStore.images)
        }
        .sheet(isPresented: $showGenerationAuth) {
            GenerationSignInSheet {
                Task {
                    let success = await runFirstRunGeneration()
                    authContinuation?.resume(returning: success)
                    authContinuation = nil
                }
            }
            .environment(appState)
        }
        .onChange(of: showGenerationAuth) { _, newValue in
            if !newValue {
                authContinuation?.resume(returning: false)
                authContinuation = nil
            }
        }
    }

    private func runFirstRunGeneration() async -> Bool {
        await viewModel.generate(showPaywall: { showPaywall = true })
        if let generated = viewModel.result?.first {
            SessionCreationsStore.add(generated)
            showResult = true
            return true
        }
        return false
    }

    private func finishFlow() {
        appState.markFirstRunComplete()
        onFinish()
    }
}
