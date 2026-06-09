import SwiftUI

struct DressingView: View {
    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()
            VStack {
                Text("Dressing")
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)
            }
        }
    }
}
