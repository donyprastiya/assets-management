//
//  ListGangguanModels.swift
//  Assets Management
//
//  Created by Dony on 24/08/25.
//

struct MaintenanceListResponse: Codable {
    let success: Bool
    let data: MaintenanceTaskData
}

struct MaintenanceTaskData: Codable {
    let tasks: [MaintenanceTaskItem]
}

struct MaintenanceTaskItem: Codable, Identifiable {
    let id: String
    let assetName: String
    let techidentno: String
    let currentStatus: String
    let updatedAt: String
    let directoryFullName: String
    let latestLog: LatestLog?

    enum CodingKeys: String, CodingKey {
        case id
        case assetName = "asset_name"
        case techidentno
        case currentStatus = "current_status"
        case updatedAt = "updated_at"
        case latestLog = "latest_log"
        case directoryFullName = "directory_full_name"
    }
}

struct LatestLog: Codable {
    let notes: String?
}
