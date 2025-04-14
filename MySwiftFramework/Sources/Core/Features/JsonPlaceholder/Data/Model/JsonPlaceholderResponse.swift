//
//  JsonPlaceholderResponse.swift
//  MySwiftFramework
//
//  Created by Francis Batista on 13/4/25.
//


public struct JsonPlaceholderResponse: Codable, Identifiable {
    public let userId: Int?
    public let id: Int?
    public let title: String?
    public let completed: Bool?
}
