import SwiftUI

// Enum untuk mendefinisikan semua kemungkinan tujuan full-screen.
// Ini membuat kode lebih aman dan mudah dibaca.
enum FullScreenDestination: Identifiable {
    case databaseAset
    case laporGangguan
    case listGangguan
    case homeAset
    case lainnya
    // Anda bisa menambahkan tujuan lain di sini, misal: .settings
    
    // Conformance ke Identifiable diperlukan oleh .fullScreenCover
    var id: FullScreenDestination { self }
}

// Class ini akan menjadi "sumber kebenaran" untuk navigasi full-screen.
class ViewRouter: ObservableObject {
    
    // @Published akan memberitahu UI untuk update saat nilainya berubah.
    // Jika nilainya bukan nil, fullScreenCover akan aktif.
    @Published var currentFullScreenDestination: FullScreenDestination?
    
    /// Fungsi untuk menampilkan sebuah view secara full-screen.
    /// Ini adalah "versi SwiftUI" dari fungsi yang Anda inginkan.
    /// - Parameter destination: View yang ingin ditampilkan.
    func show(_ destination: FullScreenDestination) {
        currentFullScreenDestination = destination
    }
    
    /// Fungsi untuk menutup view full-screen yang sedang aktif.
    func dismiss() {
        currentFullScreenDestination = nil
    }
}
