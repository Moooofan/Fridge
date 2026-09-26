import SwiftUI

/// 輸入模式
enum InputMode: String, CaseIterable {
    case text = "text"
    case photo = "photo"

    var title: String {
        switch self {
        case .text: return "文字輸入"
        case .photo: return "拍照識別"
        }
    }

    var icon: String {
        switch self {
        case .text: return "text.cursor"
        case .photo: return "camera"
        }
    }

    var description: String {
        switch self {
        case .text: return "直接輸入食材名稱"
        case .photo: return "拍攝或選擇食材照片"
        }
    }
}

/// 首頁 ViewModel
@MainActor
final class HomeViewModel: ObservableObject {
    @Published var selectedMode: InputMode?
    @Published var showMealConstraints = false

    /// 選擇輸入模式
    func selectMode(_ mode: InputMode) {
        selectedMode = mode
        showMealConstraints = true
    }

    /// 重置狀態
    func reset() {
        selectedMode = nil
        showMealConstraints = false
    }
}
