import SwiftUI

struct BoutiqueView: View {
    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()
            VStack {
                Text("Boutique")
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)
            }
        }
    }
}
