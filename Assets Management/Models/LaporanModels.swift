//
//  LaporanModels.swift
//  Assets Management
//
//  Created by Dony on 05/08/25.
//

import Foundation

struct AssetSummary: Codable {
    let id: String
    let name: String?
    let serialNumber: String?
    let categoryId: String?
    let categoryName: String?
    let directoryFullName: String?
    let directoryId: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case serialNumber = "serial_number"
        case categoryId = "category_id"
        case categoryName = "category_name"
        case directoryFullName = "directory_full_name"
        case directoryId = "directory_id"
    }
}

struct CategorySelection: Codable, Identifiable, Hashable {
    let id: String
    let name: String
}

struct PICResponse: Codable {
    let data: [FlowData]
}

struct FlowData: Codable, Identifiable {
    let id: String // ID Alur/Tahapan
    let userList: [UserList]
    
    enum CodingKeys: String, CodingKey {
        case id
        case userList = "user_list"
    }
}

struct UserList: Codable {
    let role: PICRole // Sekarang menjadi objek tunggal, bukan array
    let users: [PICUser]
}

struct PICRole: Codable, Identifiable, Hashable {
    let id: String
    let name: String
}
struct PICUser: Codable, Identifiable, Hashable {
    let id: String
    let name: String
}

struct PICSelection: Identifiable, Hashable {
    let id = UUID() // ID unik untuk UI
    let flowId: String // ID Alur/Tahapan (data.id)
    let userId: String // ID Pengguna (data.user_list.users.id)
    let userName: String // Nama Pengguna (data.user_list.users.name)
}

struct SubmitLaporanRequest: Codable {
    let assetId: String
    let newAssetName: String
    let newAssetCategory: Int
    let newAssetDirectory: Int
    let note: String
    let uploadedFiles: [String]
    let pic: [String: [Int]]

    enum CodingKeys: String, CodingKey {
        case note, pic
        case assetId = "asset_id"
        case newAssetName = "new_asset_name"
        case newAssetCategory = "new_asset_category"
        case newAssetDirectory = "new_asset_directory"
        case uploadedFiles = "uploaded_files"
    }
}

// [BARU] Model untuk respons API Submit Laporan
struct SubmitLaporanResponse: Codable {
    let success: Bool
    let message: String
}

struct DirectoryResponse: Codable {
    let success: Bool
    let data: [DirectorySelection]
}

struct DirectorySelection: Codable, Identifiable, Hashable {
    let id: String
    let prettyName: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case prettyName = "pretty_name"
    }
}

struct SubmitLaporanErrorResponse: Codable {
    let success: Bool
    let error: String
}

struct TaskListResponse: Codable {
    let success: Bool
    let data: [MaintenanceTask]
}

struct MaintenanceTask: Codable, Identifiable {
    let id: String?
    let updatedAt: String?
    let currentStatus: String?

    enum CodingKeys: String, CodingKey {
        case id
        case updatedAt = "updated_at"
        case currentStatus = "current_status"
    }
}

