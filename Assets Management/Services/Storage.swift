//
//  Storage.swift
//  Assets Management
//
//  Created by Dony on 09/07/25.
//

import Foundation

struct Storage {
    
    // Instance standar dari UserDefaults.
    private static let defaults = UserDefaults.standard
    
    // MARK: - Generic Codable Functions
    
    /// Menyimpan objek yang conform ke Codable ke UserDefaults.
    /// - Parameters:
    ///   - data: Objek yang ingin disimpan. Harus conform ke Encodable.
    ///   - key: Kunci unik untuk menyimpan data.
    static func saveData<T: Encodable>(data: T, forKey key: String) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(data) {
            defaults.set(encoded, forKey: key)
        } else {
            print("Error: Gagal melakukan encoding data untuk kunci '\(key)'")
        }
    }
    
    /// Mengambil objek yang conform ke Codable dari UserDefaults.
    /// - Parameters:
    ///   - type: Tipe data dari objek yang ingin diambil (misal: User.self). Harus conform ke Decodable.
    ///   - key: Kunci unik dari data yang disimpan.
    /// - Returns: Mengembalikan objek yang sudah di-decode, atau nil jika tidak ditemukan atau gagal decode.
    static func getData<T: Decodable>(as type: T.Type, forKey key: String) -> T? {
        if let data = defaults.object(forKey: key) as? Data {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode(T.self, from: data) {
                return decoded
            }
        }
        print("Warning: Tidak ada data yang ditemukan atau gagal decode untuk kunci '\(key)'")
        return nil
    }
    
    // MARK: - Basic Type Functions (Contoh Tambahan)
    
    /// Menyimpan String ke UserDefaults.
    static func saveString(_ string: String, forKey key: String) {
        defaults.set(string, forKey: key)
    }
    
    /// Mengambil String dari UserDefaults.
    static func getString(forKey key: String) -> String? {
        return defaults.string(forKey: key)
    }
    
    /// Menghapus data dari UserDefaults.
    static func removeData(forKey key: String) {
        defaults.removeObject(forKey: key)
    }
}
