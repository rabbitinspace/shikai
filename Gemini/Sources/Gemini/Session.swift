import Foundation

public class GeminiSession {
    public typealias SendCompletion = GeminiClient.SendCompletion

    public let client: GeminiClient

    public init(client: GeminiClient) {
        self.client = client
    }

    @discardableResult
    public func send(_ request: GeminiRequest, completion: @escaping SendCompletion) -> SessionTask {
        let sessionTask = SessionTask()
        let task = sendDetachedRequest(request) { [weak self, sessionTask] result in
            switch result {
            case let .success(response):
                self?.handleResponse(response, from: request, task: sessionTask, completion: completion)

            case let .failure(error):
                completion(.failure(error))
            }
        }

        sessionTask.replaceConnectionTask(task)
        return sessionTask
    }

    private func handleResponse(
        _ response: GeminiResponse,
        from request: GeminiRequest,
        task: SessionTask,
        completion: @escaping SendCompletion
    ) {
        switch response.header.status.type {
        case .input:
            break

        case .success, .temporaryFailire, .permanentFailure:
            task.replaceConnectionTask(nil)
            completion(.success(response))

        case .redirect:
            redirect(from: request, for: response, task: task, completion: completion)

        case .certificateRequired:
            break
        }
    }

    private func redirect(
        from request: GeminiRequest,
        for response: GeminiResponse,
        task: SessionTask,
        completion: @escaping SendCompletion
    ) {
        guard let newURL = URL(string: response.header.meta) else {
            completion(.failure(.badHeaderMeta(response.header.meta)))
            return
        }

        let newRequest = request.withURL(newURL)
        let redirectTask = sendDetachedRequest(newRequest) { [weak self, task] result in
            switch result {
            case let .success(response):
                self?.handleResponse(response, from: request, task: task, completion: completion)

            case let .failure(error):
                completion(.failure(error))
            }
        }

        if !task.replaceConnectionTask(redirectTask) {
            redirectTask.cancel()
        }
    }

    private func sendDetachedRequest(_ request: GeminiRequest, completion: @escaping SendCompletion) -> ConnectionTask {
        client.send(request, completion: completion)
    }
}

public final class SessionTask {
    private let lock = OSLock()
    private var task: ConnectionTask?
    private var isCancelled = false

    public func cancel() {
        lock.whileLocked {
            if !isCancelled {
                isCancelled = true
                task?.cancel()
                task = nil
            }
        }
    }

    @discardableResult
    func replaceConnectionTask(_ task: ConnectionTask?) -> Bool {
        lock.whileLocked {
            if !isCancelled {
                self.task = task
                return true
            }

            return false
        }
    }
}
