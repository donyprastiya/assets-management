//
//  UploadService.swift
//  Assets Management
//
//  Created by Dony on 15/07/25.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - 1. Data Model for Upload Response
// Struct ini dibuat agar cocok dengan struktur JSON dari API Anda.
// Perhatikan bahwa responsnya adalah sebuah array [UploadResponse].
struct UploadResponse: Codable {
    let propertiesId: String?
    let status: String
    let fileUrl: String

    enum CodingKeys: String, CodingKey {
        case status
        case propertiesId = "properties_id"
        case fileUrl = "file_url"
    }
}

// MARK: - 2. Upload Service
@MainActor
class UploadService {
    
    /// Fungsi untuk meng-upload satu file ke server.
    /// - Parameters:
    ///   - fileURL: URL lokal dari file yang akan di-upload.
    ///   - propertyId: ID dari properti (opsional, bisa string kosong).
    /// - Returns: URL dari file yang berhasil di-upload di server.
    /// - Throws: Melemparkan error jika upload gagal.
    static func uploadFile(fileURL: URL, propertyId: String) async throws -> String {
        
        // 1. Dapatkan token yang valid
        guard let token = await AuthenticationService.shared.getValidAccessToken() else {
            throw URLError(.userAuthenticationRequired)
        }
        
        // 2. Siapkan URL endpoint
        let urlString = "\(BaseEnv.baseURL)/asset/do_upload"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        // 3. Buat request dan boundary unik untuk multipart/form-data
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // 4. Buat body dari request
        let requestBody = createBody(
            with: ["properties_id": propertyId], // Parameter tambahan jika ada
            fileURL: fileURL,
            boundary: boundary,
            fieldName: "userfile[]" // Nama field sesuai cURL
        )
        
        // 5. Lakukan upload menggunakan URLSession
        let (data, response) = try await URLSession.shared.upload(for: request, from: requestBody)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        // 6. Decode respons JSON
        // Karena responsnya adalah array, kita decode ke [UploadResponse].self
        let decodedResponse = try JSONDecoder().decode([UploadResponse].self, from: data)
        
        // 7. Ambil URL file dari respons pertama dan kembalikan
        guard let firstResult = decodedResponse.first, firstResult.status == "success" else {
            throw URLError(.cannotParseResponse)
        }
        
        return firstResult.fileUrl
    }
    
    /// Helper untuk membuat body multipart/form-data.
    private static func createBody(with parameters: [String: String]?, fileURL: URL, boundary: String, fieldName: String) -> Data {
        var body = Data()

        // Tambahkan parameter teks jika ada
        if let parameters = parameters {
            for (key, value) in parameters {
                body.append("--\(boundary)\r\n")
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
                body.append("\(value)\r\n")
            }
        }

        // Tambahkan data file
        if let fileData = try? Data(contentsOf: fileURL) {
            let fileName = fileURL.lastPathComponent
            let mimeType = fileURL.mimeType()
            
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n")
            body.append("Content-Type: \(mimeType)\r\n\r\n")
            body.append(fileData)
            body.append("\r\n")
        }

        // Tambahkan boundary penutup
        body.append("--\(boundary)--\r\n")
        return body
    }
}

// MARK: - Helper Extensions
extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

extension URL {
    func mimeType() -> String {
        let pathExtension = self.pathExtension
        if let type = UTType(filenameExtension: pathExtension)?.preferredMIMEType {
            return type
        }
        return "application/octet-stream"
    }
}
