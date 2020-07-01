import Foundation

public class GeminiSession {
    
    public typealias SendCompletion = GeminiClient.SendCompletion
    
    public let client: GeminiClient
    
    public init(client: GeminiClient) {
        self.client = client
    }
    
    @discardableResult
    public func sendRequest(_ request: GeminiRequest, completion: @escaping SendCompletion) -> SessionTask {
        let sessionTask = SessionTask(request: request)
        let task = sendDetachedRequest(request) { [weak self, sessionTask] result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
                
            case .success(let response):
                self?.handleResponse(response, from: request, task: sessionTask, completion: completion)
            }
        }
        
        sessionTask.replaceConnectionTask(task)
        return sessionTask
    }
    
    private func handleResponse(_ response: GeminiResponse, from request: GeminiRequest, task: SessionTask, completion: @escaping SendCompletion) {
        
    }
    
    private func redirect(from request: GeminiRequest, task: SessionTask, completion: @escaping SendCompletion) {
        
    }
    
    private func sendDetachedRequest(_ request: GeminiRequest, completion: @escaping SendCompletion) -> ConnectionTask {
        client.send(request, completion: completion)
    }
}

public final class SessionTask {
    private let request: GeminiRequest
    
    private let lock = OSLock()
    private var task: ConnectionTask?
    private var isCancelled = false
    
    init(request: GeminiRequest) {
        self.request = request
    }
    
    public func cancel() {
        lock.whileLocked {
            if !isCancelled {
                isCancelled = true
                task?.cancel()
            }
        }
    }
    
    func replaceConnectionTask(_ task: ConnectionTask) {
        lock.whileLocked {
            self.task = task
        }
    }
}
