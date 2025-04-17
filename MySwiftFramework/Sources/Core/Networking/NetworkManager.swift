//
//  NetworkManager.swift
//  MySwiftFramework
//
//  Created by Francis Batista on 12/4/25.
//

import Foundation
import Combine

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

enum RequestSchemes: String {
    case https
    case http
}

protocol RequestInfo {
    var host: String { get }
    var scheme: String { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var header: [String: String]? { get }
    var body: Encodable? { get }
    var queryParams: [String: String]? { get }
    var pathParams: [String: String]? { get }
}

extension RequestInfo {
    var scheme: String {
        return RequestSchemes.https.rawValue
    }
    var host: String {
        return Constants.emptyString
    }
    var queryParams: [String : String]? {
        return nil
    }
    var pathParams: [String : String]? {
        return nil
    }
    var header: [String : String]? {
        return nil
    }
    var body: (any Encodable)? {
        return nil
    }
}

struct BasicNetworkRequest: RequestInfo {
    var host: String
    var path: String
    var method: HTTPMethod
}

protocol NetworkManagerProtocol {
    func sendRequest<T: Decodable>(requestInfo: RequestInfo, responseType: T.Type) async throws -> T
    func sendRequest<T: Decodable>(requestInfo: RequestInfo, resultHandler: @escaping (Result<T, NetworkError>) -> Void)
    func sendRequest<T: Decodable>(requestInfo: RequestInfo, type: T.Type) -> AnyPublisher<T, NetworkError>
}

extension NetworkManagerProtocol {
    fileprivate func createRequest(requestInfo: RequestInfo) -> URLRequest? {
        var urlComponents = URLComponents()
        urlComponents.scheme = requestInfo.scheme
        urlComponents.host = requestInfo.host
        urlComponents.path = requestInfo.path
        guard let url = urlComponents.url else {
            return nil
        }
        let encoder = JSONEncoder()
        var request = URLRequest(url: url)
        request.httpMethod = requestInfo.method.rawValue
        request.allHTTPHeaderFields = requestInfo.header
        if let body = requestInfo.body {
            request.httpBody = try? encoder.encode(body)
        }
        return request
    }
    
    fileprivate func manageError(error: any Error) -> NetworkError {
        if error is URLError {
            let err = error as! URLError
            switch err.code {
            case .badURL:
                return .invalidURL
            case .timedOut:
                return .requestFailed(statusCode: URLError.timedOut.rawValue)
            default:
                return .requestFailed(statusCode: err.code.rawValue)
            }
        }
        return .unknown
    }
    
    fileprivate func printRequest(request: URLRequest) {
        print("""
              ⚡️ Request: \(request)
              """)
    }
    
    fileprivate func printResponse(data: Data?, url: URL?, statusCode: Int) {
        if let data = data, let string = String(data: data, encoding: .utf8), let url = url {
            print("""
                  ⚡️ Response: \(url.absoluteString) (\(statusCode))\n\(string)
                  """)
        }
    }
}


final class NetworkManager: NSObject, NetworkManagerProtocol, Sendable {
    static let shared = NetworkManager()
    private override init() {}
    func sendRequest<T>(requestInfo: any RequestInfo, responseType: T.Type) async throws -> T where T : Decodable {
        guard let urlRequest = createRequest(requestInfo: requestInfo) else {
            throw NetworkError.unknown
        }
        printRequest(request: urlRequest)
        return try await withCheckedThrowingContinuation { continuation in
            let task = URLSession(configuration: .default, delegate: nil, delegateQueue: .main)
                .dataTask(with: urlRequest) { data, response, error in
                    self.printResponse(data: data, url: response?.url, statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
                    guard error == nil else {
                        continuation.resume(throwing: self.manageError(error: error!))
                        return
                    }
                    guard response is HTTPURLResponse else {
                        continuation.resume(throwing: NetworkError.unknown)
                        return
                    }
                    guard let response = response as? HTTPURLResponse, 200...299 ~= response.statusCode else {
                        continuation.resume(throwing: NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0))
                        return
                    }
                    guard let data = data else {
                        continuation.resume(throwing: NetworkError.unknown)
                        return
                    }
                    do {
                        let decodedResponse = try JSONDecoder().decode(T.self, from: data)
                        continuation.resume(returning: decodedResponse)
                    } catch let decodingError {
                        continuation.resume(throwing: NetworkError.decodingFailed(error: decodingError))
                    }
                }
            task.resume()
        }
    }
    
    func sendRequest<T>(requestInfo: any RequestInfo, resultHandler: @escaping (Result<T, NetworkError>) -> Void) where T : Decodable {
        guard let urlRequest = createRequest(requestInfo: requestInfo) else {
            resultHandler(.failure(.unknown))
            return
        }
        printRequest(request: urlRequest)
        let urlTask = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            self.printResponse(data: data, url: response?.url, statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
            guard error == nil else {
                resultHandler(.failure(self.manageError(error: error!)))
                return
            }
            guard let response = response as? HTTPURLResponse, 200...299 ~= response.statusCode else {
                resultHandler(.failure(.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)))
                return
            }
            guard let data = data else {
                resultHandler(.failure(.unknown))
                return
            }
            do {
                let decodedResponse = try JSONDecoder().decode(T.self, from: data)
                resultHandler(.success(decodedResponse))
            } catch let decodingError {
                resultHandler(.failure(.decodingFailed(error: decodingError)))
                return
            }
        }
        urlTask.resume()
    }
    
    func sendRequest<T>(requestInfo: any RequestInfo, type: T.Type) -> AnyPublisher<T, NetworkError> where T : Decodable {
        guard let urlRequest = createRequest(requestInfo: requestInfo) else {
            precondition(false, "Failed URLRequest")
        }
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .subscribe(on: DispatchQueue.global(qos: .background))
            .tryMap { data, response -> Data in
                guard let response = response as? HTTPURLResponse, 200...299 ~= response.statusCode else {
                    throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
                }
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error -> NetworkError in
                if error is DecodingError {
                    return NetworkError.decodingFailed(error: error)
                } else if let error = error as? NetworkError {
                    return error
                } else {
                    return NetworkError.unknown
                }
            }
            .eraseToAnyPublisher()
    }
}




//static var shared = NetworkManager()
//let timeOut: TimeInterval = 30
//let decoder: JSONDecoder = JSONDecoder()
//
//private init() {}
//
//private func performRequest(url: URL,
//                    body: Data? = nil,
//                    method: HTTPMethod = .get,
//                    headers: [String: String]? = nil) async throws -> (Data, URLResponse)  {
//    var request = URLRequest(url: url, timeoutInterval: timeOut)
//    request.httpMethod = method.rawValue
//    request.httpBody = body
//    request.allHTTPHeaderFields = headers
//    do {
//        print("""
//⚡️ Request: \(request)
//""")
//        let (data, response) = try await URLSession.shared.data(for: request)
//        let statusCode = (response as? HTTPURLResponse)!.statusCode
//        if let responseBody = String(data: data, encoding: .utf8) {
//            print("""
//⚡️ Response: \(statusCode)\nBody: \(String(describing: responseBody))
//""")
//        }
//        return (data, response)
//    } catch {
//        if let error = error as? URLError {
//            switch error.code {
//            case .badURL:
//                throw NetworkError.invalidURL
//            case .timedOut:
//                throw NetworkError.requestFailed(statusCode: URLError.timedOut.rawValue)
//            default:
//                throw NetworkError.requestFailed(statusCode: error.code.rawValue)
//            }
//        }
//        throw NetworkError.unknown
//    }
//}
//
//func request<T: Decodable>(
//    url: URL,
//    method: HTTPMethod = .get,
//    headers: [String: String]? = nil,
//    body: Data? = nil,
//    responseType: T.Type
//) async throws -> T {
//    let (data, response) = try await performRequest(url: url, body: body, method: method, headers: headers)
//    
//    guard let httpResponse = response as? HTTPURLResponse else{
//        throw NetworkError.unknown
//    }
//
//    guard (200...299).contains(httpResponse.statusCode) else {
//        throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
//    }
//
//    do {
//        let decodedData = try decoder.decode(responseType, from: data)
//        return decodedData
//    } catch {
//        throw NetworkError.decodingFailed(error: error)
//    }
//}
