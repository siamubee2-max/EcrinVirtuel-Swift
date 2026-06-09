import SwiftUI

// MARK: - Before/After Comparison Slider

struct BeforeAfterSliderView<Before: View, After: View>: View {
    let beforeLabel: String
    let afterLabel: String
    let beforeContent: Before
    let afterContent: After

    @State private var sliderPosition: CGFloat = 0.5
    @GestureState private var isDragging = false

    init(
        beforeLabel: String = "AVANT",
        afterLabel: String = "APRÈS IA",
        @ViewBuilder beforeContent: () -> Before,
        @ViewBuilder afterContent: () -> After
    ) {
        self.beforeLabel = beforeLabel
        self.afterLabel = afterLabel
        self.beforeContent = beforeContent()
        self.afterContent = afterContent()
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let dividerX = sliderPosition * width

            ZStack(alignment: .leading) {
                // BEFORE layer (full width, always visible behind)
                beforeContent
                    .frame(width: width, height: geo.size.height)
                    .clipped()

                // AFTER layer (clipped from left edge to divider)
                afterContent
                    .frame(width: width, height: geo.size.height)
                    .clipped()
                    .mask(
                        Rectangle()
                            .frame(width: dividerX, height: geo.size.height)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    )

                // Corner labels
                HStack {
                    Text(beforeLabel)
                        .font(EcrinFont.label)
                        .kerning(1.5)
                        .foregroundStyle(EcrinColor.gold)
                        .padding(.horizontal, EcrinSpacing.sm)
                        .padding(.vertical, EcrinSpacing.xs)
                        .background(.ultraThinMaterial.opacity(0.8), in: RoundedRectangle(cornerRadius: 4))
                        .padding([.top, .leading], EcrinSpacing.sm)
                    Spacer()
                    Text(afterLabel)
                        .font(EcrinFont.label)
                        .kerning(1.5)
                        .foregroundStyle(EcrinColor.gold)
                        .padding(.horizontal, EcrinSpacing.sm)
                        .padding(.vertical, EcrinSpacing.xs)
                        .background(.ultraThinMaterial.opacity(0.8), in: RoundedRectangle(cornerRadius: 4))
                        .padding([.top, .trailing], EcrinSpacing.sm)
                }
                .frame(maxHeight: .infinity, alignment: .top)

                // Divider line + handle
                ZStack {
                    // Vertical gold line
                    Rectangle()
                        .fill(EcrinColor.gold)
                        .frame(width: 2, height: geo.size.height)

                    // Circle handle at vertical center
                    ZStack {
                        Circle()
                            .fill(EcrinColor.background)
                            .frame(width: 32, height: 32)
                        Circle()
                            .stroke(EcrinColor.gold, lineWidth: 1.5)
                            .frame(width: 32, height: 32)
                        HStack(spacing: 2) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 9, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundStyle(EcrinColor.gold)
                    }
                    .scaleEffect(isDragging ? 1.12 : 1.0)
                    .animation(EcrinAnimation.springSnap, value: isDragging)
                }
                .offset(x: dividerX - 1) // center the 2pt line on dividerX
                .frame(width: 2, height: geo.size.height, alignment: .center)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isDragging) { _, state, _ in state = true }
                    .onChanged { value in
                        let newPos = value.location.x / width
                        withAnimation(EcrinAnimation.springSnap) {
                            sliderPosition = newPos.clamped(to: 0.1...0.9)
                        }
                    }
            )
        }
    }
}

