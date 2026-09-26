import SwiftUI

struct CondimentManagementView: View {
    @EnvironmentObject var condimentVM: CondimentViewModel
    @State private var customCondimentName = ""
    @State private var selectedCategoryId: UUID?
    @State private var showCategorySheet = false
    @State private var editingCategory: CondimentCategory?

    var body: some View {
        List {
            // 已新增的調味料
            if condimentVM.hasCondiments {
                Section {
                    ForEach(condimentVM.condiments) { condiment in
                        CondimentRow(
                            condiment: condiment,
                            category: condimentVM.category(for: condiment.categoryId)
                        )
                    }
                    .onDelete { offsets in
                        condimentVM.removeCondiment(at: offsets)
                    }
                } header: {
                    HStack {
                        Text("我的調味料")
                        Spacer()
                        Text("\(condimentVM.count) 項")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } footer: {
                    Text("AI 會根據這些調味料推薦適合的食譜")
                }
            }

            // 快速新增建議
            Section {
                ForEach(condimentVM.categories) { category in
                    let suggestions = condimentVM.filteredSuggestions(for: category)

                    if !suggestions.isEmpty {
                        DisclosureGroup {
                            FlowLayout(spacing: 8) {
                                ForEach(suggestions, id: \.name) { suggestion in
                                    SuggestionChip(name: suggestion.name) {
                                        condimentVM.addCondimentFromSuggestion(suggestion)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        } label: {
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundColor(.secondary)
                                    .frame(width: 24)
                                Text(category.name)
                            }
                        }
                    }
                }
            } header: {
                Text("快速新增")
            } footer: {
                Text("點擊可快速新增常見調味料")
            }

            // 自訂新增
            Section {
                HStack {
                    TextField("自訂調味料名稱", text: $customCondimentName)
                        .submitLabel(.done)
                        .onSubmit {
                            addCustomCondiment()
                        }

                    if !customCondimentName.isEmpty {
                        Button {
                            addCustomCondiment()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.black)
                        }
                    }
                }

                Picker("類別", selection: $selectedCategoryId) {
                    ForEach(condimentVM.categories) { category in
                        Text(category.name).tag(category.id as UUID?)
                    }
                }
            } header: {
                Text("自訂新增")
            }

            // 類別管理
            Section {
                ForEach(condimentVM.categories) { category in
                    CategoryRow(
                        category: category,
                        count: condimentVM.condimentCount(in: category)
                    ) {
                        editingCategory = category
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        let category = condimentVM.categories[index]
                        condimentVM.removeCategory(category)
                    }
                }

                Button {
                    showCategorySheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.black)
                        Text("新增類別")
                            .foregroundColor(.primary)
                    }
                }
            } header: {
                Text("類別管理")
            } footer: {
                Text("自訂調味料類別，刪除類別會一併刪除該類別下的調味料")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("調味料設定")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if condimentVM.hasCondiments {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
        .sheet(isPresented: $showCategorySheet) {
            CategoryEditSheet(
                category: nil,
                onSave: { category in
                    condimentVM.addCategory(category)
                }
            )
        }
        .sheet(item: $editingCategory) { category in
            CategoryEditSheet(
                category: category,
                onSave: { updatedCategory in
                    condimentVM.updateCategory(updatedCategory)
                }
            )
        }
        .onAppear {
            if selectedCategoryId == nil, let first = condimentVM.categories.first {
                selectedCategoryId = first.id
            }
        }
    }

    private func addCustomCondiment() {
        guard let categoryId = selectedCategoryId else { return }
        condimentVM.addCustomCondiment(name: customCondimentName, categoryId: categoryId)
        customCondimentName = ""
    }
}

// MARK: - Condiment Row

private struct CondimentRow: View {
    let condiment: Condiment
    let category: CondimentCategory?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category?.icon ?? "ellipsis.circle.fill")
                .foregroundColor(.secondary)
                .frame(width: 24)

            Text(condiment.name)

            Spacer()

            Text(category?.name ?? "其他")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Category Row

private struct CategoryRow: View {
    let category: CondimentCategory
    let count: Int
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                Image(systemName: category.icon)
                    .foregroundColor(.secondary)
                    .frame(width: 24)

                Text(category.name)
                    .foregroundColor(.primary)

                Spacer()

                if count > 0 {
                    Text("\(count) 項")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Suggestion Chip

private struct SuggestionChip: View {
    let name: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(name)
                    .font(.subheadline)
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .foregroundColor(.primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category Edit Sheet

private struct CategoryEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let category: CondimentCategory?
    let onSave: (CondimentCategory) -> Void

    @State private var name: String = ""
    @State private var selectedIcon: String = "ellipsis.circle.fill"

    var isEditing: Bool {
        category != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("類別名稱", text: $name)
                } header: {
                    Text("名稱")
                }

                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(CondimentCategory.availableIcons, id: \.self) { icon in
                            IconButton(
                                icon: icon,
                                isSelected: selectedIcon == icon
                            ) {
                                selectedIcon = icon
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("圖示")
                }
            }
            .navigationTitle(isEditing ? "編輯類別" : "新增類別")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let category = category {
                    name = category.name
                    selectedIcon = category.icon
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let updatedCategory: CondimentCategory
        if let existing = category {
            updatedCategory = CondimentCategory(
                id: existing.id,
                name: trimmedName,
                icon: selectedIcon
            )
        } else {
            updatedCategory = CondimentCategory(
                name: trimmedName,
                icon: selectedIcon
            )
        }

        onSave(updatedCategory)
        dismiss()
    }
}

// MARK: - Icon Button

private struct IconButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isSelected ? .white : .primary)
                .frame(width: 44, height: 44)
                .background(isSelected ? Color.black : Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        CondimentManagementView()
            .environmentObject(CondimentViewModel())
    }
}
