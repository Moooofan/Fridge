import SwiftUI
import PhotosUI

struct PhotoInputView: View {
    @ObservedObject var ingredientVM: IngredientViewModel
    @State private var showReviewView = false
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var selectedItem: PhotosPickerItem?
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 照片區域
                VStack(spacing: 16) {
                    if let image = ingredientVM.selectedImage {
                        // 已選照片
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    ingredientVM.selectedImage = nil
                                    ingredientVM.recognitionError = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                        .shadow(radius: 2)
                                }
                                .padding(8)
                            }

                        // AI 辨識狀態／操作
                        if ingredientVM.isRecognizing {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("AI 辨識中…")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Button {
                                Task { await ingredientVM.recognizeFromPhoto() }
                            } label: {
                                HStack {
                                    Image(systemName: "sparkles")
                                    Text("重新辨識食材")
                                }
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }

                        if let recognitionError = ingredientVM.recognitionError {
                            Text(recognitionError)
                                .font(.caption)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        // 選擇照片區
                        VStack(spacing: 16) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 48, weight: .light))
                                .foregroundColor(.secondary)

                            Text("選擇或拍攝食材照片")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            HStack(spacing: 16) {
                                // 相簿按鈕
                                PhotosPicker(selection: $selectedItem, matching: .images) {
                                    HStack {
                                        Image(systemName: "photo.stack")
                                        Text("相簿")
                                    }
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)
                                    .frame(width: 120, height: 44)
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }

                                // 拍照按鈕
                                Button {
                                    showCamera = true
                                } label: {
                                    HStack {
                                        Image(systemName: "camera")
                                        Text("拍照")
                                    }
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.white)
                                    .frame(width: 120, height: 44)
                                    .background(Color.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .background(Color(.systemGray6).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [8]))
                                .foregroundColor(.secondary)
                        )
                    }
                }
                .padding(.horizontal, 24)

                // 補充說明
                VStack(alignment: .leading, spacing: 12) {
                    Text("補充說明食材")
                        .font(.subheadline.weight(.medium))

                    Text("照片可能無法完整識別，請手動補充")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ZStack(alignment: .topLeading) {
                        if ingredientVM.photoNote.isEmpty {
                            Text("例如：雞蛋、番茄、洋蔥...")
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 12)
                        }

                        TextEditor(text: $ingredientVM.photoNote)
                            .focused($isTextFieldFocused)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 80)
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isTextFieldFocused ? Color.black : Color(.systemGray4), lineWidth: 1)
                    )

                    // 新增按鈕
                    if !ingredientVM.photoNote.isEmpty {
                        Button {
                            ingredientVM.parsePhotoNote()
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
                }
                .padding(.horizontal, 24)

                // 已新增的食材
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
                    .padding(.horizontal, 24)
                }

                Spacer(minLength: 100)
            }
            .padding(.top, 24)
        }
        .safeAreaInset(edge: .bottom) {
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
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showReviewView) {
            IngredientReviewView(ingredientVM: ingredientVM)
        }
        .sheet(isPresented: $showCamera) {
            CameraView(image: $ingredientVM.selectedImage) {
                ingredientVM.recognitionError = nil
                Task { await ingredientVM.recognizeFromPhoto() }
            }
        }
        .onChange(of: selectedItem) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    ingredientVM.selectedImage = image
                    ingredientVM.recognitionError = nil
                    await ingredientVM.recognizeFromPhoto()
                }
            }
        }
        .onTapGesture {
            isTextFieldFocused = false
        }
    }

    private var canProceed: Bool {
        !ingredientVM.ingredients.isEmpty || !ingredientVM.photoNote.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func proceedToReview() {
        // 先解析剩餘的輸入
        if !ingredientVM.photoNote.isEmpty {
            ingredientVM.parsePhotoNote()
        }
        showReviewView = true
    }
}

// MARK: - Camera View

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onCapture: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
                parent.onCapture?()
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        PhotoInputView(ingredientVM: IngredientViewModel())
    }
}
