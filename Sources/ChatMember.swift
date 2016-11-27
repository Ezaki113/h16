import PerfectWebSockets

class ChatMember {
    let id: Int
    let name: String
    let photoUrl: String
    let admin: Bool

    var sockets: [WebSocket?] = []
    var socketId: Int = 0

    init(id: Int, name: String, photoUrl: String, admin: Bool) {
        self.id = id
        self.name = name
        self.photoUrl = photoUrl
        self.admin = admin
    }

    func append(socket: WebSocket) -> Int
    {
        sockets.insert(socket, at: socketId)

        let p = socketId

        socketId += 1

        return p
    }

    func close(socketId: Int)
    {
        guard let socket = sockets[socketId] else {
            return
        }

        socket.close()

        sockets[socketId] = nil
    }

    func sendStringMessage(string: String, final: Bool, completion: @escaping () -> ()) {
        let _ = sockets.filter {
            return $0 != nil && $0!.isConnected
        }.map {
            $0!.sendStringMessage(string: string, final: final, completion: completion)
        }
    }
}


extension ChatMember : Equatable {
    public static func ==(lhs: ChatMember, rhs: ChatMember) -> Bool {
        return lhs.id == rhs.id
    }

    public static func !=(lhs: ChatMember, rhs: ChatMember) -> Bool {
        return lhs.id != rhs.id
    }
}