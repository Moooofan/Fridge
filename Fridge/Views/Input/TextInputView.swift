import SwiftUI

struct TextInputView: View {
    @ObservedObject var ingredientVM: IngredientViewModel
    @State private var showReviewView = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 說明區
            VStack(spacing: 8) {
                Image(systemName: "text.cursor")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.primary)
                    .padding(.bottom, 8)

                Text("輸入食材")
                    .font(.title2.bold())

                Text("以逗號、頓號或換行分隔")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 24)
            .padding(.bottom, 32)

            // 輸入區
            VStack(spacing: 16) {
                // Text Editor
                ZStack(alignment: .topLeading) {
                    if ingredientVM.textInput.isEmpty {
                        Text("例如：雞蛋、番茄、洋蔥、青椒...")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 12)
                    }

                    TextEditor(text: $ingredientVM.textInput)
                        .focused($isTextFieldFocused)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 120)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isTextFieldFocused ? Color.black : Color(.systemGray4), lineWidth: 1)
                )

                // 快速新增按鈕
                if !ingredientVM.textInput.isEmpty {
                    Button {
                        ingredientVM.parseTextInput()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("新增到食材清單")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                // 已新增的食材預覽
                if !ingredientVM.ingredients.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("已新增")
                                .font(.subheadline.weight(.medium))
                            Text("(\(ingredientVM.ingredientCount))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }

                        FlowLayout(spacing: 8) {
                            ForEach(ingredientVM.ingredients) { ingredient in
                                IngredientTag(
                                    name: ingredient.name,
                                    onRemove: {
                                        ingredientVM.removeIngredient(ingredient)
                                    }
                                )
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // 下一步按鈕
            Button(action: proceedToReview) {
                HStack {
                    Text("確認食材")
                        .font(.headline)
                    Image(systemName: "arrow.right")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(canProceed ? Color.black : Color(.systemGray4))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!canProceed)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showReviewView) {
            IngredientReviewView(ingredientVM: ingredientVM)
        }
        .onTapGesture {
            isTextFieldFocused = false
        }
    }

    private var canProceed: Bool {
        !ingredientVM.ingredients.isEmpty || !ingredientVM.textInput.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func proceedToReview() {
        // 先解析剩餘的輸入
        if !ingredientVM.textInput.isEmpty {
            ingredientVM.parseTextInput()
        }
        showReviewView = true
    }
}


#Preview {
    NavigationStack {
        TextInputView(ingredientVM: IngredientViewModel())
    }
}
