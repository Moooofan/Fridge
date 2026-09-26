import SwiftUI

/// App 品牌標誌（與 App Icon 同一張圖：綠底、奶油色冰箱、嫩芽），
/// 以 iOS App Icon 的圓角比例（0.2237）裁切，用於新手導覽第一頁、登入與首頁標題。
struct BrandMarkView: View {
    let size: CGFloat

    var body: some View {
        Image("BrandMark")
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
            .accessibilityLabel("Fridge")
    }
}
