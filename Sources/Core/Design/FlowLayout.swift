import SwiftUI

// MARK: - Flow Layout
// Lays out subviews in a left-to-right wrapping flow, similar to CSS flexbox wrap.

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let containerWidth = proposal.width ?? .infinity
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var rowWidth: CGFloat = 0

        for subview in subviews {
            let dim = subview.dimensions(in: proposal)
            let w = dim.width
            let h = dim.height

            if rowWidth + w > containerWidth, rowWidth > 0 {
                y += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += w + spacing
            rowHeight = max(rowHeight, h)
        }
        y += rowHeight
        return CGSize(width: containerWidth, height: max(y, 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let containerWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        // First pass: compute row heights so we can place by row
        var rows: [[LayoutSubviews.Element]] = [[]]
        var rowWidth: CGFloat = 0

        for subview in subviews {
            let w = subview.dimensions(in: proposal).width
            if rowWidth + w > containerWidth, !rows[rows.count - 1].isEmpty {
                rows.append([])
                rowWidth = 0
            }
            rows[rows.count - 1].append(subview)
            rowWidth += w + spacing
        }

        // Second pass: place
        for row in rows {
            rowHeight = row.map { $0.dimensions(in: proposal).height }.max() ?? 0
            x = bounds.minX
            for subview in row {
                let dim = subview.dimensions(in: proposal)
                subview.place(
                    at: CGPoint(x: x, y: y + (rowHeight - dim.height) / 2),
                    proposal: .unspecified
                )
                x += dim.width + spacing
            }
            y += rowHeight + spacing
        }
    }
}
