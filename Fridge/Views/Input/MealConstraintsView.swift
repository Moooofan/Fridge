import SwiftUI

struct MealConstraintsView: View {
    @ObservedObject var ingredientVM: IngredientViewModel
    let inputMode: InputMode

    @State private var showNextView = false

    // 日期與餐次
    @State private var selectedDate = Date()
    @State private var selectedMealType: MealType = .dinner

    // 本地狀態（用於 Stepper）
    @State private var servingsEnabled = false
    @State private var servingsValue = 2

    @State private var dishesEnabled = false
    @State private var dishesValue = 2

    @State private var soupsEnabled = false
    @State private var soupsValue = 1

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 標題區
                VStack(spacing: 8) {
                    Text("用餐設定")
                        .font(.title2.bold())
                        .foregroundColor(.primary)

                    Text("設定用餐時間與份量")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 24)
                .padding(.bottom, 24)

                // 設定項目
                VStack(spacing: 20) {
                    // 日期選擇
                    DatePickerRow(selectedDate: $selectedDate)

                    Divider()

                    // 餐次選擇
                    MealTypeRow(selectedMealType: $selectedMealType)

                    Divider()

                    // 用餐人數
                    ConstraintRow(
                        icon: "person.2",
                        title: "用餐人數",
                        isEnabled: $servingsEnabled,
                        value: $servingsValue,
                        range: 1...10,
                        unit: "人"
                    )

                    Divider()

                    // 菜的數量
                    ConstraintRow(
                        icon: "fork.knife",
                        title: "菜的數量",
                        isEnabled: $dishesEnabled,
                        value: $dishesValue,
                        range: 1...6,
                        unit: "道"
                    )

                    Divider()

                    // 湯的數量
                    ConstraintRow(
                        icon: "cup.and.saucer",
                        title: "湯的數量",
                        isEnabled: $soupsEnabled,
                        value: $soupsValue,
                        range: 0...3,
                        unit: "道"
                    )
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 100)
            }
        }
        .safeAreaInset(edge: .bottom) {
            // 下一步按鈕
            Button(action: proceedToNext) {
                HStack {
                    Text("下一步")
                        .font(.headline)
                    Image(systemName: "arrow.right")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showNextView) {
            if inputMode == .text {
                TextInputView(ingredientVM: ingredientVM)
            } else {
                PhotoInputView(ingredientVM: ingredientVM)
            }
        }
    }

    private func proceedToNext() {
        // 更新 ViewModel
        ingredientVM.constraints.date = selectedDate
        ingredientVM.constraints.mealType = selectedMealType
        ingredientVM.constraints.servings = servingsEnabled ? servingsValue : nil
        ingredientVM.constraints.dishesCount = dishesEnabled ? dishesValue : nil
        ingredientVM.constraints.soupsCount = soupsEnabled ? soupsValue : nil

        showNextView = true
    }
}

// MARK: - Date Picker Row

private struct DatePickerRow: View {
    @Binding var selectedDate: Date

    // 產生未來7天的日期選項
    private var dateOptions: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Date()) }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")

        if Calendar.current.isDateInToday(date) {
            return "今天"
        } else if Calendar.current.isDateInTomorrow(date) {
            return "明天"
        } else {
            formatter.dateFormat = "E M/d"
            return formatter.string(from: date)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(.primary)
                    .frame(width: 32)

                Text("用餐日期")
                    .font(.body)
                    .foregroundColor(.primary)
            }

            // 橫向滾動的日期選擇
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(dateOptions, id: \.self) { date in
                        DateChip(
                            title: formatDate(date),
                            isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                            action: { selectedDate = date }
                        )
                    }
                }
            }
        }
    }
}

private struct DateChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? Color.black : Color(.systemGray6))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Meal Type Row

private struct MealTypeRow: View {
    @Binding var selectedMealType: MealType

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(.primary)
                    .frame(width: 32)

                Text("餐次")
                    .font(.body)
                    .foregroundColor(.primary)
            }

            // 餐次選擇
            HStack(spacing: 8) {
                ForEach(MealType.allCases) { mealType in
                    MealTypeChip(
                        mealType: mealType,
                        isSelected: selectedMealType == mealType,
                        action: { selectedMealType = mealType }
                    )
                }
            }
        }
    }
}

private struct MealTypeChip: View {
    let mealType: MealType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: mealType.icon)
                    .font(.system(size: 14))
                Text(mealType.displayName)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? Color.black : Color(.systemGray6))
            .clipShape(Capsule())
        }
    }
}

// MARK: - Constraint Row

private struct ConstraintRow: View {
    let icon: String
    let title: String
    @Binding var isEnabled: Bool
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String

    var body: some View {
        VStack(spacing: 16) {
            // Header with toggle
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(.primary)
                    .frame(width: 32)

                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)

                Spacer()

                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .tint(.black)
            }

            // Stepper (shown when enabled)
            if isEnabled {
                HStack {
                    Spacer()

                    // Minus button
                    Button {
                        if value > range.lowerBound {
                            value -= 1
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(value > range.lowerBound ? .primary : .secondary)
                            .frame(width: 44, height: 44)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                    .disabled(value <= range.lowerBound)

                    // Value display
                    Text("\(value) \(unit)")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .frame(width: 80)

                    // Plus button
                    Button {
                        if value < range.upperBound {
                            value += 1
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(value < range.upperBound ? .primary : .secondary)
                            .frame(width: 44, height: 44)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                    .disabled(value >= range.upperBound)

                    Spacer()
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}

#Preview {
    NavigationStack {
        MealConstraintsView(
            ingredientVM: IngredientViewModel(),
            inputMode: .text
        )
    }
}
