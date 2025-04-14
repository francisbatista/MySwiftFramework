//
//  JsonPlaceholderInteractor.swift
//  MySwiftFramework
//
//  Created by Francis Batista on 13/4/25.
//


public class JsonPlaceholderUsecase {
    private let remoteRepository: JsonPlaceholderRemoteRepository
    public init() {
        self.remoteRepository = JsonPlaceholderRemoteRepository()
    }
    
    internal init(networkManager: NetworkManagerProtocol) {
        self.remoteRepository = JsonPlaceholderRemoteRepository(networkManager: networkManager)
    }
    
    public func getJsonPlaceholderData(id: Int) async -> Result<JsonPlaceholderResponse, NetworkError> {
        return await remoteRepository.getJsonPlaceholderData(id: id)
    }
    
    public func getAllJsonPlaceholderData() async -> Result<[JsonPlaceholderResponse], NetworkError> {
        return await remoteRepository.getAllJsonPlaceholderData()
    }
}
