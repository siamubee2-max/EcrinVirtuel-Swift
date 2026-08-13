import SwiftUI

struct BoutiqueView: View {
    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()
            VStack {
                Text(L10n.Home.boutique)
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)
            }
        }
    }
}
