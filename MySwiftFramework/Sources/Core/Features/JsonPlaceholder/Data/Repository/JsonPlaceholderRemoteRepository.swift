//
//  JsonPlaceholderRemoteRepository.swift
//  MySwiftFramework
//
//  Created by Francis Batista on 13/4/25.
//

enum ExampleApi {
    static let baseURL = URL(string: "https://jsonplaceholder.typicode.com")!
    
    static func todos() -> URL {
        return baseURL.appendingPathComponent("todos")
    }
    
    static func todo(id: Int) -> URL {
        return baseURL.appendingPathComponent("todos").appendingPathComponent("\(id)")
    }
}

class JsonPlaceholderRemoteRepository {
    let networkManager: NetworkManagerProtocol
    
    init(networkManager: NetworkManagerProtocol = NetworkManager.shared) {
        self.networkManager = networkManager
    }
    
    func getJsonPlaceholderData(id: Int) async -> Result<JsonPlaceholderResponse, NetworkError> {
        do {
            let response = try await networkManager.request(url: ExampleApi.todo(id: id),
                                                  method: .get,
                                                  headers: nil,
                                                  body: nil,
                                                  responseType: JsonPlaceholderResponse.self)
            return .success(response)
        } catch {
            return .failure(error as! NetworkError)
        }
    }
    
    func getAllJsonPlaceholderData() async -> Result<[JsonPlaceholderResponse], NetworkError> {
        do {
            let response = try await networkManager.request(url: ExampleApi.todos(), method: .get, headers: nil, body: nil, responseType: [JsonPlaceholderResponse].self)
            return .success(response)
        } catch {
            return .failure(error as! NetworkError)
        }
    }
}
