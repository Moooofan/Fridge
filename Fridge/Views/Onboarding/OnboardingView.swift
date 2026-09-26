import SwiftUI

// MARK: - Onboarding Page Model

private struct OnboardingPage: Identifiable {
    let id: Int
    let icon: String
    let title: String
    let lines: [String]
}

private let onboardingPages: [OnboardingPage] = [
    OnboardingPage(
        id: 0,
        icon: "refrigerator.fill",
        title: "把冰箱裡有的，變成今晚的菜",
        lines: [
            "輸入你手邊的食材，Fridge 幫你配出一桌家常菜，",
            "少買、少浪費。"
        ]
    ),
    OnboardingPage(
        id: 1,
        icon: "camera.fill",
        title: "兩種輸入方式",
        lines: [
            "打字輸入食材，或直接拍一張冰箱／食材照片，",
            "AI 會辨識出食材，你再確認增減。"
        ]
    ),
    OnboardingPage(
        id: 2,
        icon: "person.2.fill",
        title: "告訴我們怎麼吃",
        lines: [
            "幾個人吃、幾道菜、幾道湯、哪一餐；",
            "也可以在設定裡登記家裡常備的調味料與過敏食材。"
        ]
    ),
    OnboardingPage(
        id: 3,
        icon: "book.closed.fill",
        title: "以專業廚師食譜為底",
        lines: [
            "內建 146 道阿基師、詹姆士、楊桃美食網等專業食譜，",
            "AI 以它們為基礎配菜，每道都標明參考來源，",
            "份量依人數換算。"
        ]
    ),
    OnboardingPage(
        id: 4,
        icon: "checkmark.circle.fill",
        title: "邊煮邊勾",
        lines: [
            "步驟可逐一勾選，喜歡的收藏起來，煮過的留在歷史；",
            "沒網路或 AI 忙線時也有內建食譜可用。"
        ]
    )
]

// MARK: - Onboarding View

struct OnboardingView: View {
    @EnvironmentObject var appFlow: AppFlowState
    @State private var currentPage = 0

    private var isLastPage: Bool { currentPage == onboardingPages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            // Skip button
            HStack {
                Spacer()
                Button("略過") {
                    finish()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }

            // Pages
            TabView(selection: $currentPage) {
                ForEach(onboardingPages) { page in
                    OnboardingPageView(page: page)
                        .tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Custom page dots
            HStack(spacing: 8) {
                ForEach(onboardingPages) { page in
                    Circle()
                        .fill(page.id == currentPage ? Color.black : Color(.systemGray4))
                        .frame(width: page.id == currentPage ? 8 : 6, height: page.id == currentPage ? 8 : 6)
                        .animation(.easeInOut(duration: 0.2), value: currentPage)
                }
            }
            .padding(.bottom, 24)

            // Bottom button
            Button(action: advance) {
                Text(isLastPage ? "開始使用" : "下一步")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
    }

    private func advance() {
        if isLastPage {
            finish()
        } else {
            withAnimation {
                currentPage += 1
            }
        }
    }

    private func finish() {
        appFlow.completeOnboarding()
    }
}

// MARK: - Single Page

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer(minLength: 24)

                    // Hero icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color.black)
                            .frame(width: 120, height: 120)

                        Image(systemName: page.icon)
                            .font(.system(size: 44, weight: .light))
                            .foregroundColor(.white)
                    }

                    VStack(spacing: 12) {
                        Text(page.title)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(spacing: 4) {
                            ForEach(page.lines, id: \.self) { line in
                                Text(line)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.horizontal, 32)

                    Spacer(minLength: 24)
                }
                .frame(minHeight: geo.size.height)
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppFlowState())
}
