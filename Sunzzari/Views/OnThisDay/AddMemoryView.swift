import SwiftUI
import PhotosUI

struct AddMemoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var date = Date()
    @State private var category: Memory.Category = .memory
    @State private var notes = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.miraclesBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Title
                        field(label: "Title", icon: "textformat") {
                            TextField("e.g. First trip to Paris", text: $title)
                                .padding()
                                .background(Color.miraclesSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(Color.miraclesText)
                        }

                        // Date
                        field(label: "Date", icon: "calendar") {
                            DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .tint(.miraclesAccent)
                                .padding()
                                .background(Color.miraclesSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Category
                        field(label: "Category", icon: "tag") {
                            HStack(spacing: 8) {
                                ForEach(Memory.Category.allCases, id: \.self) { cat in
                                    Button {
                                        category = cat
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    } label: {
                                        Text("\(cat.emoji) \(cat.rawValue)")
                                            .font(.system(.caption, design: .serif, weight: .semibold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(
                                                category == cat
                                                    ? Color(hex: cat.colorHex).opacity(0.3)
                                                    : Color.miraclesSurface
                                            )
                                            .foregroundStyle(
                                                category == cat
                                                    ? Color(hex: cat.colorHex)
                                                    : Color.miraclesSecondary
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .strokeBorder(
                                                        category == cat
                                                            ? Color(hex: cat.colorHex)
                                                            : Color.clear,
                                                        lineWidth: 1.5
                                                    )
                                            )
                                    }
                                }
                            }
                        }

                        // Notes
                        field(label: "Notes (optional)", icon: "note.text") {
                            TextField("What made this moment special?", text: $notes, axis: .vertical)
                                .lineLimit(3...6)
                                .padding()
                                .background(Color.miraclesSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(Color.miraclesText)
                        }

                        // Optional photo
                        field(label: "Photo (optional)", icon: "photo") {
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.miraclesSurface)
                                        .frame(height: 140)
                                    if let image = selectedImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 140)
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    } else {
                                        VStack(spacing: 8) {
                                            Image(systemName: "photo.badge.plus")
                                                .font(.system(.title, design: .serif))
                                                .foregroundStyle(Color.miraclesAccent)
                                            Text("Add a photo")
                                                .font(.system(.caption, design: .serif))
                                                .foregroundStyle(Color.miraclesSecondary)
                                        }
                                    }
                                }
                            }
                            .onChange(of: selectedItem) { _, newItem in
                                Task {
                                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                                       let img = UIImage(data: data) {
                                        selectedImage = img
                                    }
                                }
                            }
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(.caption, design: .serif))
                                .foregroundStyle(.red)
                        }

                        Button {
                            Task { await save() }
                        } label: {
                            HStack(spacing: 10) {
                                if isSaving { ProgressView().tint(.miraclesBackground) }
                                Text(isSaving ? "Saving..." : "Save Memory")
                                    .font(.system(.headline, design: .serif))
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(title.isEmpty ? Color.miraclesSurface : Color.miraclesAccent)
                            .foregroundStyle(title.isEmpty ? Color.miraclesSecondary : Color.miraclesBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(title.isEmpty || isSaving)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("New Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.miraclesSecondary)
                }
            }
        }
    }

    private func field<Content: View>(label: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: icon)
                .font(.system(.caption, design: .serif, weight: .semibold))
                .foregroundStyle(Color.miraclesSecondary)
            content()
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            var photoURL: String?
            if let image = selectedImage {
                photoURL = try await CloudinaryService.shared.upload(image: image)
            }
            let memory = Memory(
                id:       UUID().uuidString,
                title:    title,
                date:     date,
                category: category,
                notes:    notes,
                photoURL: photoURL
            )
            try await NotionService.shared.createMemory(memory)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
