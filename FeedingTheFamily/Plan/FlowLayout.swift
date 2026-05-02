import SwiftUI

/// Wrap children onto multiple rows when they exceed the available width.
/// Used for chip lists (avoidances, etc.) where the count is variable.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var rowSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[CGSize]] = [[]]
        var rowWidth: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, !rows[rows.count - 1].isEmpty {
                rows.append([])
                rowWidth = 0
            }
            rows[rows.count - 1].append(size)
            rowWidth += size.width + spacing
        }

        let totalHeight = rows.reduce(into: CGFloat(0)) { acc, row in
            let h = row.map(\.height).max() ?? 0
            acc += h + rowSpacing
        } - rowSpacing
        let totalWidth = rows.map { row in
            row.reduce(0) { $0 + $1.width } + CGFloat(max(0, row.count - 1)) * spacing
        }.max() ?? 0
        return CGSize(width: min(totalWidth, maxWidth), height: max(totalHeight, 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + rowSpacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), anchor: .topLeading,
                       proposal: ProposedViewSize(width: size.width, height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            _ = maxWidth
        }
    }
}
