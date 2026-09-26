import SwiftUI

struct LoadingView: View {
    let message: String

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 24) {
            // Animated icon
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 3)
                    .frame(width: 64, height: 64)

                // Animated arc
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(Color.black, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 64, height: 64)
                    .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                    .animation(
                        .linear(duration: 1)
                        .repeatForever(autoreverses: false),
                        value: isAnimating
                    )

                // Center icon
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.primary)
            }

            // Message
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Tips
            LoadingTips()
        }
        .padding(32)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Loading Tips

private struct LoadingTips: View {
    @State private var currentTipIndex = 0

    private let tips = [
        "正在分析您的食材...",
        "尋找最佳料理組合...",
        "計算營養均衡...",
        "準備詳細步驟...",
        "最佳化烹飪時間..."
    ]

    // Use TimelineView for proper SwiftUI lifecycle management instead of Timer
    var body: some View {
        TimelineView(.periodic(from: .now, by: 2.0)) { timeline in
            let index = Int(timeline.date.timeIntervalSince1970 / 2) % tips.count
            Text(tips[index])
                .font(.caption)
                .foregroundColor(.secondary)
                .animation(.easeInOut, value: index)
        }
    }
}

#Preview {
    LoadingView(message: "AI 正在為您設計菜單...")
}

// MARK: - Flow Layout

/// A layout that arranges views in a flowing manner, wrapping to new lines when needed.
struct FlowLayout: Layout {
    var spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(
                    x: bounds.minX + result.positions[index].x,
                    y: bounds.minY + result.positions[index].y
                ),
                proposal: .unspecified
            )
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let itemSize = subview.sizeThatFits(.unspecified)

                if x + itemSize.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, itemSize.height)
                x += itemSize.width + spacing
                self.size.width = max(self.size.width, x - spacing)
            }

            self.size.height = y + rowHeight
        }
    }
}

// MARK: - Ingredient Tag

/// Reusable ingredient tag component displayed as a capsule chip
struct IngredientTag: View {
    let name: String
    let onRemove: (() -> Void)?

    init(name: String, onRemove: (() -> Void)? = nil) {
        self.name = name
        self.onRemove = onRemove
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(name)
                .font(.subheadline)

            if let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(Capsule())
    }
}
