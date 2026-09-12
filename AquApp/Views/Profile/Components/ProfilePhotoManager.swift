//
//  ProfilePhotoManager.swift
//  AquApp
//
//  Created by Fabian Dargaud on 12/09/2026.
//


import SwiftUI
import PhotosUI
import Combine

// MARK: - ProfilePhotoManager
// Persiste la photo de profil sur disque (Application Support).
// Aucun permission requise : PhotosPicker tourne hors processus.

@MainActor
final class ProfilePhotoManager: ObservableObject {
    static let shared = ProfilePhotoManager()

    @Published private(set) var image: UIImage?

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("profile_photo.jpg")
    }

    private init() { load() }

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let img  = UIImage(data: data) else { image = nil; return }
        image = img
    }

    func set(_ data: Data) {
        guard let src = UIImage(data: data) else { return }
        // Downscale 512 pt max → fichier léger (~100 Ko)
        let maxDim: CGFloat = 512
        let scale   = min(1, maxDim / max(src.size.width, src.size.height))
        let newSize = CGSize(width: src.size.width * scale, height: src.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized  = renderer.image { _ in
            src.draw(in: CGRect(origin: .zero, size: newSize))
        }
        guard let jpeg = resized.jpegData(compressionQuality: 0.85) else { return }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try jpeg.write(to: fileURL, options: .atomic)
            image = resized
        } catch {
            print("⚠️ ProfilePhotoManager — échec sauvegarde: \(error)")
        }
    }

    func remove() {
        try? FileManager.default.removeItem(at: fileURL)
        image = nil
    }
}

// MARK: - ProfileAvatarView
// Avatar cliquable : tap = galerie photo, appui long = retirer la photo.
// Sans photo → initiale du prénom sur fond dégradé (comportement actuel).

struct ProfileAvatarView: View {
    let firstName: String
    let background: AnyShapeStyle
    var size: CGFloat = 70

    @ObservedObject private var photoManager = ProfilePhotoManager.shared
    @State private var pickerItem: PhotosPickerItem?
    @State private var isLoading = false

    var body: some View {
        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
            avatar
                .overlay(alignment: .bottomTrailing) { cameraBadge }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if photoManager.image != nil {
                Button(role: .destructive) {
                    photoManager.remove()
                } label: {
                    Label("Retirer la photo", systemImage: "trash")
                }
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            isLoading = true
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    photoManager.set(data)
                }
                isLoading = false
                pickerItem = nil
            }
        }
        .accessibilityLabel("Photo de profil")
        .accessibilityHint("Touchez pour choisir une photo dans la galerie")
    }

    // MARK: Avatar

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(background)
                .frame(width: size, height: size)

            if let photo = photoManager.image {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(.white)
            }

            if isLoading {
                Circle()
                    .fill(.black.opacity(0.35))
                    .frame(width: size, height: size)
                ProgressView().tint(.white)
            }
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.2), value: photoManager.image != nil)
    }

    // MARK: Pastille caméra

    private var cameraBadge: some View {
        ZStack {
            Circle()
                .fill(Color("AppCardBackground"))
                .frame(width: 24, height: 24)
            Image(systemName: photoManager.image == nil ? "camera.fill" : "arrow.triangle.2.circlepath")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(hex: "4DA8F5"))
        }
        .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
    }

    private var initials: String {
        let name = firstName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return "?" }
        return String(name.prefix(1)).uppercased()
    }
}
