import Foundation

final class LinkBuilder {
    private enum State {
        case prelink
        case link(Int, Int)
        case pretext
        case text(Int, Int)
    }
    
    private var state = State.prelink
}
