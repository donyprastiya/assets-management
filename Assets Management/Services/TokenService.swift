//
//  TokenService.swift.swift
//  Assets Management
//
//  Created by Dony on 01/07/25.
//

import Foundation
import Security

// Struct untuk merepresentasikan data yang sudah di-decode dari payload JWT
struct DecodedToken: Decodable {
    // Klaim standar JWT
    let iat: Date // Issued At
    let exp: Date // Expiration Time
    
    // Payload data kustom Anda
    let data: UserData
    
    struct UserData: Decodable {
        let id: String
        let name: String
        let nip: String
        let email: String
        let roles: [Role]
    }
    
    struct Role: Decodable {
        let id: String
        let name: String
    }
}

// Service untuk mengelola penyimpanan, pengambilan, dan decoding token JWT.
// Dibuat sebagai Singleton agar bisa diakses dari mana saja.
class TokenService {
    
    static let shared = TokenService()
    private init() {} // Private init untuk memastikan hanya ada satu instance
    
    // Kunci unik untuk menyimpan data di Keychain
    private let accessTokenKey = "accessToken"
    private let refreshTokenKey = "refreshToken"
    
    // MARK: - Public Methods
    
    /// Menyimpan access token dan refresh token ke Keychain.
    func saveTokens(accessToken: String, refreshToken: String) {
        // Simpan access token
        saveToKeychain(key: accessTokenKey, data: Data(accessToken.utf8))
        
        // Simpan refresh token
        saveToKeychain(key: refreshTokenKey, data: Data(refreshToken.utf8))
    }
    
    /// Mengambil access token dari Keychain.
    func getAccessToken() -> String? {
        guard let tokenData = getFromKeychain(key: accessTokenKey) else { return nil }
        return String(data: tokenData, encoding: .utf8)
    }
    
    /// Mengambil refresh token dari Keychain.
    func getRefreshToken() -> String? {
        guard let tokenData = getFromKeychain(key: refreshTokenKey) else { return nil }
        return String(data: tokenData, encoding: .utf8)
    }
    
    /// Menghapus semua token dari Keychain (untuk logout).
    func deleteTokens() {
        deleteFromKeychain(key: accessTokenKey)
        deleteFromKeychain(key: refreshTokenKey)
    }
    
    /// Mendekode token JWT untuk mendapatkan payload-nya.
    func decode(jwtToken jwt: String) -> DecodedToken? {
        // 1. Pisahkan token menjadi 3 bagian: Header, Payload, Signature
        let segments = jwt.components(separatedBy: ".")
        guard segments.count > 1 else {
            print("Error: Token tidak valid.")
            return nil
        }
        
        // 2. Ambil bagian payload (bagian kedua)
        var base64String = segments[1]
        
        // 3. Tambahkan padding jika diperlukan agar valid untuk decoding Base64
        let requiredPadding = 4 - base64String.count % 4
        if requiredPadding < 4 {
            base64String += String(repeating: "=", count: requiredPadding)
        }
        
        // 4. Decode dari Base64 ke Data
        guard let decodedData = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters) else {
            print("Error: Gagal decode Base64.")
            return nil
        }
        
        // 5. Decode dari JSON Data ke struct DecodedToken
        do {
            let decoder = JSONDecoder()
            // JWT menggunakan detik sejak 1970, jadi kita atur strategi decoding tanggal
            decoder.dateDecodingStrategy = .secondsSince1970
            let token = try decoder.decode(DecodedToken.self, from: decodedData)
            return token
        } catch {
            print("Error: Gagal decode JSON dari payload token: \(error)")
            return nil
        }
    }

    // MARK: - Keychain Helper Methods
    
    private func saveToKeychain(key: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        // Hapus item lama jika ada
        SecItemDelete(query as CFDictionary)
        
        // Tambahkan item baru
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Error saving to Keychain: \(status)")
        }
    }
    
    private func getFromKeychain(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            return dataTypeRef as? Data
        } else {
            // Tidak perlu print error jika item tidak ditemukan (errSecItemNotFound)
            return nil
        }
    }
    
    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            print("Error deleting from Keychain: \(status)")
        }
    }
}
