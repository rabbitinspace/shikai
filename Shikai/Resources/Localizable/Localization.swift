import Foundation

enum Localizable {
    enum App {}
}

extension Localizable.App {
    static var name: String {
        NSLocalizedString("Shikai", comment: "Main app name")
    }
}
