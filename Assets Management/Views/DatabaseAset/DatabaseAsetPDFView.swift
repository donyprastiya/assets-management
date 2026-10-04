import SwiftUI
import PDFKit // Diperlukan untuk menampilkan PDF

// MARK: - Helper Class & Structs

/// Kelas helper untuk mengunduh file dari URL.
/// Proses ini diperlukan agar file bisa dibagikan.
class FileDownloader {
    static func downloadFile(from urlString: String) async throws -> URL {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        var fileExtension = "tmp"
        if let mimeType = response.mimeType {
            switch mimeType {
            case "application/pdf": fileExtension = "pdf"
            case "image/jpeg": fileExtension = "jpg"
            case "image/png": fileExtension = "png"
            case "image/gif": fileExtension = "gif"
            default:
                if !url.pathExtension.isEmpty { fileExtension = url.pathExtension }
            }
        } else if !url.pathExtension.isEmpty {
            fileExtension = url.pathExtension
        }

        let fileName = UUID().uuidString + "." + fileExtension
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        
        try data.write(to: fileURL)
        
        return fileURL
    }
}

/// Wrapper untuk URL agar bisa digunakan dengan modifier .sheet(item: ...).
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

/// Wrapper untuk UIActivityViewController (Share Sheet) agar bisa digunakan di SwiftUI.
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}


// MARK: - Main View
struct DatabaseAsetPDFView: View {
    
    let urlString: String
    let title: String
    
    @State private var isLoading = true
    @State private var isDownloading = false
    
    @State private var downloadedFileURL: IdentifiableURL?
    @State private var showDownloadErrorAlert = false
    
    @Environment(\.dismiss) var dismiss
    
    private enum ContentType {
        case pdf, image, unsupported
    }
    
    private var contentType: ContentType {
        if urlString.lowercased().hasSuffix(".pdf") { return .pdf }
        else if let _ = URL(string: urlString) { return .image }
        else { return .unsupported }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // Tombol untuk menutup bottom sheet
                Button(action: {
                    dismiss()
                    // Aksi untuk menutup, misalnya: dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .font(.title2)
                        .foregroundColor(.black)
                }
                
                Spacer() // Mendorong judul ke tengah
                
                Text(title)
                    .font(.custom("Inter18pt-SemiBold", size: 16))
                    .foregroundColor(.black)
                
                Spacer() // Menjaga agar judul tetap di tengah
                
                // Menambahkan view kosong agar spacer berfungsi dengan benar
                // dan tombol kembali tidak mempengaruhi posisi tengah judul.
                Image(systemName: "arrow.left")
                    .font(.title2)
                    .opacity(0) // Dibuat tidak terlihat
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            ZStack {
                switch contentType {
                case .pdf:
                    PDFKitView(urlString: urlString, isLoading: $isLoading)
                case .image:
                    RemoteImageView(urlString: urlString, isLoading: $isLoading)
                case .unsupported:
                    Text("Format file atau URL tidak didukung.")
                        .foregroundColor(.secondary)
                        .onAppear { isLoading = false }
                }
                
                if isLoading {
                    ProgressView().scaleEffect(1.5)
                }
            }
            
            // Tombol untuk mengunduh lalu membagikan file
            Button(action: {
                // Gunakan Task untuk memanggil fungsi async
                Task {
                    isDownloading = true
                    do {
                        // Langkah 1: Unduh file ke direktori sementara
                        let localURL = try await FileDownloader.downloadFile(from: urlString)
                        // Langkah 2: Jika berhasil, picu Share Sheet dengan URL lokal
                        self.downloadedFileURL = IdentifiableURL(url: localURL)
                    } catch {
                        // Jika terjadi error, tampilkan alert
                        print("Download gagal: \(error)")
                        self.showDownloadErrorAlert = true
                    }
                    isDownloading = false
                }
            }) {
                if isDownloading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    // [PERUBAHAN] Teks tombol diubah agar lebih jelas
                    Text("Unduh File")
                        .font(.custom("Inter18pt-SemiBold", size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color(hex: BaseEnv.baseColor))
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding()
            .background(Color.white)
            .disabled(isDownloading)
        }
        .background(Color.white)
        .navigationBarBackButtonHidden(true)
        // Tampilkan Share Sheet saat downloadedFileURL memiliki nilai
        .sheet(item: $downloadedFileURL) { identifiableURL in
            ShareSheet(activityItems: [identifiableURL.url])
        }
        .alert("Gagal", isPresented: $showDownloadErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Tidak dapat mengunduh file untuk dibagikan. Periksa koneksi internet Anda.")
        }
    }
}

// MARK: - PDF Viewer (Wrapper untuk PDFKit)
struct PDFKitView: UIViewRepresentable {
    
    let urlString: String
    @Binding var isLoading: Bool
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            if let url = URL(string: urlString), let document = PDFDocument(url: url) {
                DispatchQueue.main.async {
                    pdfView.document = document
                    isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    print("Error: Gagal memuat PDF dari URL.")
                    isLoading = false
                }
            }
        }
        
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// MARK: - Image Viewer (Wrapper untuk AsyncImage)
struct RemoteImageView: View {
    let urlString: String
    @Binding var isLoading: Bool
    
    var body: some View {
        AsyncImage(url: URL(string: urlString)) { phase in
            switch phase {
            case .empty:
                Color.clear
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .onAppear { isLoading = false }
            case .failure:
                VStack {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                    Text("Gagal memuat gambar")
                }
                .foregroundColor(.secondary)
                .onAppear { isLoading = false }
            @unknown default:
                EmptyView()
            }
        }
    }
}


// MARK: - Preview Provider
struct DatabaseAsetPDFView_Previews: PreviewProvider {
    static var previews: some View {
        
        NavigationView {
            DatabaseAsetPDFView(
                urlString: "https://picsum.photos/id/237/400/600",
                title: "Contoh Gambar"
            )
        }
        .previewDisplayName("Image Viewer")
    }
}
