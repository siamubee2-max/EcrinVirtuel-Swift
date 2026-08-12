import SwiftUI

struct DressingView: View {
    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()
            VStack {
                Text(L10n.MultiPoseUI.dressing)
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)
            }
        }
    }
}
