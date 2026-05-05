import SwiftUI

struct GalleryView: View {
    @State private var photos: [FamilyPhoto] = []
    @State private var isLoading = true
    @State private var selectedPhoto: FamilyPhoto?
    @State private var showAddPhoto = false
    @State private var showBulkImport = false
    @State private var errorMessage: String?
    @State private var favoritesOnly = false

    private let columns = [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)]

    private var displayPhotos: [FamilyPhoto] {
        let base = favoritesOnly ? photos.filter(\.isFavorite) : photos
        return base.filter(\.isFavorite) + base.filter { !$0.isFavorite }
    }

    var body: some View {
        // Reached as a nested destination from HubView (which owns the NavigationStack).
        // Do NOT wrap in another NavigationStack — nested stacks cause double nav bars.
        ZStack {
            Color.miraclesBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                SerifNavHeader("Gallery")

                if isLoading {
                    LoadingView()
                } else if photos.isEmpty {
                    EmptyStateView(
                        systemImage: "photo.badge.plus",
                        title: "No photos yet",
                        subtitle: "Add your first photo to start the gallery!"
                    )
                } else {
                    // Filter bar
                    HStack(spacing: 8) {
                        Button {
                            favoritesOnly.toggle()
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: favoritesOnly ? "star.fill" : "star")
                                    .font(.system(size: 11, weight: .semibold, design: .serif))
                                Text("Favorites")
                                    .font(.system(size: 13, weight: favoritesOnly ? .semibold : .regular, design: .serif))
                            }
                            .foregroundStyle(favoritesOnly ? Color.miraclesAccent : Color.miraclesSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(favoritesOnly ? Color.miraclesAccent.opacity(0.12) : Color.miraclesSurface)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(
                                favoritesOnly ? Color.miraclesAccent.opacity(0.8) : Color.miraclesChipStroke,
                                lineWidth: 1
                            ))
                            .shadow(color: favoritesOnly ? Color.miraclesAccent.opacity(0.3) : .clear, radius: 6)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    Color.miraclesDivider.frame(height: 0.5)

                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(displayPhotos) { photo in
                                GalleryCell(photo: photo, onFavoriteTap: { toggleFavorite(photo) })
                                    .onTapGesture { selectedPhoto = photo }
                            }
                        }
                        .padding(4)
                    }
                    .refreshable { await loadPhotos(force: true) }
                }
            }

            // FABs
            VStack {
                Spacer()
                HStack {
                    // Bulk import button
                    Button {
                        showBulkImport = true
                    } label: {
                        Image(systemName: "photo.stack.fill")
                            .font(.system(.title3, design: .serif, weight: .semibold))
                            .foregroundStyle(Color.miraclesAccent)
                            .frame(width: 48, height: 48)
                            .background(Color.miraclesSurface)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                    }
                    .padding(.leading, 20)

                    Spacer()

                    // Single add button
                    Button {
                        showAddPhoto = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(.title2, design: .serif, weight: .semibold))
                            .foregroundStyle(Color.miraclesBackground)
                            .frame(width: 56, height: 56)
                            .background(Color.miraclesAccent)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                    }
                    .padding(.trailing, 20)
                }
                .padding(.bottom, 8)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedPhoto) { photo in
            PhotoDetailView(photo: photo, onFavoriteToggle: { toggleFavorite($0) }, onEdit: { updated in
                if let idx = photos.firstIndex(where: { $0.id == updated.id }) {
                    photos[idx] = updated
                }
            })
        }
        .sheet(isPresented: $showAddPhoto) {
            AddPhotoView { newPhoto in
                photos.insert(newPhoto, at: 0)
            }
        }
        .sheet(isPresented: $showBulkImport) {
            BulkImportView { newPhotos in
                photos.insert(contentsOf: newPhotos.reversed(), at: 0)
            }
        }
        .task { await loadPhotos() }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func loadPhotos(force: Bool = false) async {
        // Stale-while-revalidate: serve disk cache instantly, refresh in background
        if !force, let cached = NotionService.shared.photosDiskCache() {
            photos = cached
            isLoading = false
            do {
                let fresh = try await NotionService.shared.fetchPhotos(force: true)
                photos = fresh
            } catch is CancellationError {
            } catch let urlErr as URLError where urlErr.code == .cancelled {
            } catch { /* silently fail — user already sees cached data */ }
            return
        }
        // No disk cache (first-ever launch) or pull-to-refresh
        isLoading = true
        defer { isLoading = false }
        do {
            photos = try await NotionService.shared.fetchPhotos(force: force)
        } catch is CancellationError {
            return
        } catch let urlErr as URLError where urlErr.code == .cancelled {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleFavorite(_ photo: FamilyPhoto) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        guard let idx = photos.firstIndex(where: { $0.id == photo.id }) else { return }
        let newValue = !photos[idx].isFavorite
        photos[idx].isFavorite = newValue
        Task {
            try? await NotionService.shared.toggleFavorite(pageID: photo.id, isFavorite: newValue)
        }
    }
}

// MARK: - Gallery Cell
private struct GalleryCell: View {
    let photo: FamilyPhoto
    let onFavoriteTap: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    AsyncImageView(urlString: photo.cloudinaryURL, cornerRadius: 8, thumbnailWidth: 500)
                        .scaledToFill()
                        .clipped()
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Button {
                onFavoriteTap()
            } label: {
                Image(systemName: photo.isFavorite ? "star.fill" : "star")
                    .font(.system(.caption, design: .serif, weight: .bold))
                    .foregroundStyle(photo.isFavorite ? Color.miraclesAccent : Color.white.opacity(0.8))
                    .padding(6)
                    .background(.ultraThinMaterial, in: Circle())
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
