//
//  Untitled.swift
//  Assets Management
//
//  Created by Dony on 30/07/25.
//

struct QRCodePayload: Codable {
    let type: String
    let value: String
}

struct AssetDetailResponse: Codable {
    let id: String?
    let categoryId: String?
    let directoryId: String?
    var name: String?
    var serialNumber: String?
    var categoryName: String?
    var lastUpdate: String?
    var directoryFullName: String?
    var properties: [AssetProperty]

    enum CodingKeys: String, CodingKey {
        case id, name, properties
        case categoryId = "category_id"
        case directoryId = "directory_id"
        case serialNumber = "serial_number"
        case categoryName = "category_name"
        case lastUpdate = "updated_at"
        case directoryFullName = "directory_full_name"
    }
    
    // Custom decoder untuk menangani struktur 'properties' yang kompleks
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId)
        self.directoryId = try container.decodeIfPresent(String.self, forKey: .directoryId)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.serialNumber = try container.decodeIfPresent(String.self, forKey: .serialNumber)
        self.categoryName = try container.decodeIfPresent(String.self, forKey: .categoryName)
        self.lastUpdate = try container.decodeIfPresent(String.self, forKey: .lastUpdate)
        self.directoryFullName = try container.decodeIfPresent(String.self, forKey: .directoryFullName) // <-- DITAMBAHKAN
        
        var propertiesArray: [AssetProperty] = []
        if let propertiesContainer = try? container.decode([String: AssetProperty].self, forKey: .properties) {
            propertiesArray = Array(propertiesContainer.values)
        } else if let propertiesArrayContainer = try? container.decode([AssetProperty].self, forKey: .properties) {
            propertiesArray = propertiesArrayContainer
        } else {
            var nestedContainer = try container.nestedUnkeyedContainer(forKey: .properties)
            while !nestedContainer.isAtEnd {
                let propertyDict = try nestedContainer.decode([String: AssetProperty].self)
                propertiesArray.append(contentsOf: propertyDict.values)
            }
        }
        self.properties = propertiesArray
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(categoryId, forKey: .categoryId)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(serialNumber, forKey: .serialNumber)
        try container.encodeIfPresent(categoryName, forKey: .categoryName)
        try container.encodeIfPresent(lastUpdate, forKey: .lastUpdate)
        try container.encodeIfPresent(directoryFullName, forKey: .directoryFullName)
        try container.encode(properties, forKey: .properties)
    }
}

struct AssetProperty: Codable, Identifiable {
    let id: String
    let name: String
    let columnType: String
    var values: [PropertyValue]

    enum CodingKeys: String, CodingKey {
        case id, name
        case columnType = "column_type"
        case values
    }
}

struct PropertyValue: Codable, Identifiable {
    let id: String
    var propertyValues: String

    enum CodingKeys: String, CodingKey {
        case id
        case propertyValues = "property_values"
    }
}


struct EditAssetRequest: Codable {
    let id: Int
    let name: String
    let serialNumber: String
    let techidentno: String
    let categoryId: Int
    let directoryId: Int
    let properties: [PropertyEditItem]
    let filesToDelete: [Int]

    enum CodingKeys: String, CodingKey {
        case id, name, properties
        case serialNumber = "serial_number"
        case techidentno = "techidentno"
        case categoryId = "category_id"
        case directoryId = "directory_id"
        case filesToDelete = "files_to_delete"
    }
}

struct PropertyEditItem: Codable {
    let id: Int
    let value: String
}

struct DeleteFilesRequest: Codable {
    let files: [String]
}

struct DeleteFilesResponse: Codable {
    let status: String
    let message: String
}
