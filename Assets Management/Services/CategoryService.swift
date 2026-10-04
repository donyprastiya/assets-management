//
//  CategoryService.swift
//  Assets Management
//
//  Created by Dony on 14/07/25.
//

import Foundation
import SwiftUI

// MARK: - 1. Data Models for Category API Response
// Struct ini dibuat agar cocok dengan struktur JSON dari API Anda.

struct CategoryDetailResponse: Codable, Identifiable {
    let id: String
    let name: String
    let properties: [CategoryProperty]
    
    enum CodingKeys: String, CodingKey {
        case id, name, properties
    }
}

struct CategoryProperty: Codable, Identifiable {
    let id: String
    let name: String
    let columnType: String
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case columnType = "column_type"
    }
}


// MARK: - 2. ViewModel
@MainActor
class CategoryViewModel: ObservableObject {
    
    @Published var categoryDetail: CategoryDetailResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    /// Fungsi untuk mengambil detail kategori berdasarkan ID.
    /// - Parameter categoryId: ID dari kategori yang ingin diambil.
    func getCategory(categoryId: String) async {
        isLoading = true
        errorMessage = nil
        
        // 1. Buat URL yang benar
        let urlString = "\(BaseEnv.baseURL)/asset/get_category_by_id/\(categoryId)"
        guard let url = URL(string: urlString) else {
            errorMessage = "URL tidak valid."; isLoading = false; return
        }
        
        // 2. Dapatkan token yang valid (otomatis refresh jika perlu)
        guard let token = await AuthenticationService.shared.getValidAccessToken() else {
            errorMessage = "Sesi Anda telah berakhir. Silakan login kembali."; isLoading = false; return
        }
        
        // 3. Siapkan request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // 4. Lakukan panggilan API
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            
            // 5. Decode respons JSON ke dalam model data kita
            let decodedResponse = try JSONDecoder().decode(CategoryDetailResponse.self, from: data)
            self.categoryDetail = decodedResponse
            print("Berhasil mengambil data untuk kategori: \(decodedResponse.name)")
            
        } catch {
            self.errorMessage = "Gagal mengambil data kategori: \(error.localizedDescription)"
            print("API Error: \(error)")
        }
        
        isLoading = false
    }
}
