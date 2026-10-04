//
//  LaporGangguanPreviewView.swift
//  Assets Management
//
//  Created by Dony on 05/08/25.
//

import SwiftUI

@MainActor
class LaporGangguanPreviewViewModel: ObservableObject {
    @Published var isUploading = false
    @Published var errorMessage: String?
    
    /// Fungsi untuk meng-upload gambar dan mengembalikan URL dari server.
    func uploadPhoto(image: UIImage) async -> String? {
        isUploading = true
        errorMessage = nil
        
        // Buat nama file yang unik
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let fileName = "LaporGangguan_\(timestamp).jpg"
        
        // Simpan gambar ke file sementara
        guard let data = image.jpegData(compressionQuality: 1) else {
            errorMessage = "Gagal mengonversi gambar."
            isUploading = false
            return nil
        }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: tempURL)
        } catch {
            errorMessage = "Gagal menyimpan file sementara."
            isUploading = false
            return nil
        }
        
        // Panggil service untuk upload
        do {
            let serverURL = try await UploadService.uploadFile(fileURL: tempURL, propertyId: "")
            isUploading = false
            return serverURL
        } catch {
            errorMessage = "Gagal meng-upload file: \(error.localizedDescription)"
            isUploading = false
            return nil
        }
    }
}

struct LaporGangguanPreviewView: View {
    @StateObject private var viewModel = LaporGangguanPreviewViewModel()
    
    let image: UIImage
    // [PERBAIKAN] Callback sekarang mengirimkan URL file dan nama file
    var onSave: (String, String) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var showAlert = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()

            VStack {
                Spacer()
                
                HStack(spacing: 20) {
                    // Tombol Ulangi
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Ulangi")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.white)
                            .foregroundColor(Color(hex: BaseEnv.baseColor))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(hex: BaseEnv.baseColor), lineWidth: 2)
                            )
                    }
                    .disabled(viewModel.isUploading)

                    // Tombol Gunakan Foto
                    Button(action: {
                        // Jalankan proses upload di dalam Task
                        Task {
                            if let serverURL = await viewModel.uploadPhoto(image: image) {
                                // Jika sukses, panggil callback dengan URL dan nama file
                                let fileName = URL(string: serverURL)?.lastPathComponent ?? "uploaded_file.jpg"
                                onSave(fileName, serverURL)
                                dismiss()
                            } else {
                                // Jika gagal, tampilkan alert
                                showAlert = true
                            }
                        }
                    }) {
                        if viewModel.isUploading {
                            ProgressView().tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(hex: BaseEnv.baseColor))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        } else {
                            Text("Gunakan Foto")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(hex: BaseEnv.baseColor))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .disabled(viewModel.isUploading)
                }
                .padding()
            }
        }
        .alert("Upload Gagal", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Terjadi kesalahan yang tidak diketahui.")
        }
        
    }
}

// MARK: - Preview Provider
struct LaporGangguanPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        if let placeholderImage = UIImage(systemName: "photo") {
            LaporGangguanPreviewView(image: placeholderImage, onSave: { _, _ in })
        } else {
            Text("Placeholder image not available")
        }
    }
}
