//
//  NetworkManager.swift
//  MySwiftFramework
//
//  Created by Francis Batista on 12/4/25.
//

import Foundation

public enum NetworkError: Error, LocalizedError {
    case invalidURL
    case decodingFailed(error: Error)
    case encodingFailed(error: Error)
    case requestFailed(statusCode: Int)
    case noData
    case unknown
    case custom(message: String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL."
        case .requestFailed(let statusCode):
            return "Request failed with status code: \(statusCode)."
        case .noData:
            return "No data received."
        case .decodingFailed(let error):
            return "Error decoding data: \(error.localizedDescription)"
        case .encodingFailed(let error):
            return "Error encoding data: \(error.localizedDescription)"
        case .unknown:
            return "An unknown error occurred."
        case .custom(let message):
            return message
        }
    }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

protocol NetworkManagerProtocol {
    func request<T: Decodable>(
        url: URL,
        method: HTTPMethod,
        headers: [String: String]?,
        body: Data?,
        responseType: T.Type
    ) async throws -> T
}

struct NetworkManager: NetworkManagerProtocol {
    static var shared = NetworkManager()
    let timeOut: TimeInterval = 30
    let decoder: JSONDecoder = JSONDecoder()
    
    private init() {}
    
    private func performRequest(url: URL,
                        body: Data? = nil,
                        method: HTTPMethod = .get,
                        headers: [String: String]? = nil) async throws -> (Data, URLResponse)  {
        var request = URLRequest(url: url, timeoutInterval: timeOut)
        request.httpMethod = method.rawValue
        request.httpBody = body
        request.allHTTPHeaderFields = headers
        do {
            print("""
⚡️ Request: \(request)
""")
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)!.statusCode
            if let responseBody = String(data: data, encoding: .utf8) {
                print("""
    ⚡️ Response: \(statusCode)\nBody: \(String(describing: responseBody))
    """)
            }
            return (data, response)
        } catch {
            if let error = error as? URLError {
                switch error.code {
                case .badURL:
                    throw NetworkError.invalidURL
                case .timedOut:
                    throw NetworkError.requestFailed(statusCode: URLError.timedOut.rawValue)
                default:
                    throw NetworkError.requestFailed(statusCode: error.code.rawValue)
                }
            }
            throw NetworkError.unknown
        }
    }
    
    func request<T: Decodable>(
        url: URL,
        method: HTTPMethod = .get,
        headers: [String: String]? = nil,
        body: Data? = nil,
        responseType: T.Type
    ) async throws -> T {
        let (data, response) = try await performRequest(url: url, body: body, method: method, headers: headers)
        
        guard let httpResponse = response as? HTTPURLResponse else{
            throw NetworkError.unknown
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
        }

        do {
            let decodedData = try decoder.decode(responseType, from: data)
            return decodedData
        } catch {
            throw NetworkError.decodingFailed(error: error)
        }
    }
}
