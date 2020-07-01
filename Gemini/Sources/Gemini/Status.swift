import Foundation

public enum GeminiStatus: Int {
    case input = 10
    case sensitiveInput = 11

    case success = 20

    case redirectTemporary = 30
    case redirectPermanent = 31

    case temporaryFailure = 40
    case serverUnavailable = 41
    case cgiError = 42
    case proxyError = 43
    case slowDown = 44

    case permanentFailure = 50
    case notFound = 51
    case gone = 52
    case proxyRequestRefused = 53
    case badRequest = 54

    case clientCertificateRequired = 60
    case certificateNotAuthorised = 61
    case certificateNotValid = 62
}

public extension GeminiStatus {
    enum StatusType: Int {
        case input = 1
        case success
        case redirect
        case temporaryFailire
        case permanentFailure
        case certificateRequired
    }

    var type: StatusType {
        guard let type = StatusType(rawValue: rawValue / 10) else {
            preconditionFailure("Status \(rawValue) is not defined")
        }

        return type
    }
}
