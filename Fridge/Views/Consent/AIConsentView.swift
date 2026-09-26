import SwiftUI

/// 第一次使用 AI 功能（產生食譜／照片辨識）前顯示的揭露與同意畫面
/// （App Store Guideline 5.1.2(i)）。選擇結果寫入 `AIConsentStore`，
/// 再透過 `onDecision(granted)` 通知呼叫端。
struct AIConsentView: View {
    let onDecision: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss

    static let privacyURL = URL(string: "https://fridge-site.vercel.app/privacy.html")!

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40, weight: .light))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 32)

                    Text("使用 AI 功能前")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 14) {
                        bullet("paperplane",
                               "你輸入的食材、用餐條件，以及你選擇辨識的照片，會透過我們的伺服器傳送給 OpenAI，用來產生食譜與辨識食材。")
                        bullet("photo",
                               "我們的伺服器不保存你的照片。OpenAI 依其 API 資料政策處理：預設不用於訓練模型，為防濫用最多保留 30 天。")
                        bullet("hand.raised",
                               "這些資料不會用來追蹤你，也不會用於廣告。")
                        bullet("arrow.uturn.backward",
                               "你可以隨時在「設定 > AI 資料使用」變更這個選擇。不同意的話，仍可使用內建食譜離線配菜（不會傳送任何資料）。")
                    }

                    Link(destination: Self.privacyURL) {
                        HStack(spacing: 4) {
                            Text("閱讀完整隱私權政策")
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                        .font(.subheadline)
                    }
                    .tint(.primary)
                    .underline()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }

            VStack(spacing: 12) {
                Button {
                    AIConsentStore.grant()
                    onDecision(true)
                    dismiss()
                } label: {
                    Text("同意並繼續")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button {
                    AIConsentStore.decline()
                    onDecision(false)
                    dismiss()
                } label: {
                    Text("不同意")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .interactiveDismissDisabled()
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .frame(width: 24)
                .foregroundColor(.secondary)
            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    AIConsentView { _ in }
}
