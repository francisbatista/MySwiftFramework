//
//  JsonPlaceholderRemoteRepository.swift
//  MySwiftFramework
//
//  Created by Francis Batista on 13/4/25.
//

enum ExampleApi {
    static let host = "jsonplaceholder.typicode.com"
    
    static func todosPath() -> String {
        return "/todos"
    }
    
    static func todoIdPath(id: Int) -> String {
        return "/todos/\(id)"
    }
}

class JsonPlaceholderRemoteRepository {
    let networkManager: NetworkManagerProtocol
    
    init(networkManager: NetworkManagerProtocol = NetworkManager.shared) {
        self.networkManager = networkManager
    }
    
    func getJsonPlaceholderData(id: Int) async -> Result<JsonPlaceholderResponse, NetworkError> {
        do {
            let networkRequest = BasicNetworkRequest(host: ExampleApi.host, path: ExampleApi.todoIdPath(id: id), method: .get)
            let response = try await networkManager.sendRequest(requestInfo: networkRequest, responseType: JsonPlaceholderResponse.self)
            return .success(response)
        } catch {
            return .failure(error as! NetworkError)
        }
    }
    
    func getJsonPlaceholderData(id: Int, resultHandler: @escaping (Result<JsonPlaceholderResponse, NetworkError>) -> Void) {
        let networkRequest = BasicNetworkRequest(host: ExampleApi.host, path: ExampleApi.todoIdPath(id: id), method: .get)
        networkManager.sendRequest(requestInfo: networkRequest) { result in
            DispatchQueue.main.async {
                resultHandler(result)
            }
        }
    }
    
    func getAllJsonPlaceholderData() async -> Result<[JsonPlaceholderResponse], NetworkError> {
        do {
            let networkRequest = BasicNetworkRequest(host: ExampleApi.host, path: ExampleApi.todosPath(), method: .get)
            let response = try await networkManager.sendRequest(requestInfo: networkRequest, responseType: [JsonPlaceholderResponse].self)
            return .success(response)
        } catch {
            return .failure(error as! NetworkError)
        }
    }
    
    func getAllJsonPlaceholderData(resultHandler: @escaping (Result<[JsonPlaceholderResponse], NetworkError>) -> Void) {
        let networkRequest = BasicNetworkRequest(host: ExampleApi.host, path: ExampleApi.todosPath(), method: .get)
        networkManager.sendRequest(requestInfo: networkRequest) { result in
            DispatchQueue.main.async {
                resultHandler(result)
            }
        }
    }
}
