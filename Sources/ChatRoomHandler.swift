import PerfectLib
import PerfectWebSockets
import PerfectHTTP
import PerfectHTTPServer
import CryptoSwift

class ChatRoomHandler: WebSocketSessionHandler {
    let socketProtocol: String? = nil

    let groupId: Int
    var members: [Int : ChatMember] = [:]

    var topic: String? = nil

    init(groupId: Int) {
        self.groupId = groupId
    }

    func addMemberIfNotExists(id: Int, name: String, photoUrl: String, admin: Bool) -> ChatMember
    {
        var member = members[id]

        if member == nil {
            member = ChatMember(id: id, name: name, photoUrl: photoUrl, admin: admin)

            members[id] = member
        }

        return member!
    }

    func handleSession(request: HTTPRequest, socket: WebSocket) {
        guard
            var hash = request.urlVariables[routeTrailingWildcardKey]?.stringByDecodingURL else {
            socket.close()

            return
        }

        hash.remove(at: hash.startIndex)
        hash = hash.replacingOccurrences(of: " ", with: "+")
                   .replacingOccurrences(of: "/magicstring/", with: "//")

        guard
            let cipher = try? Blowfish(key: KEY, blockMode: .CBC, padding: PKCS7()),
            let decrypted = try? hash.decryptBase64ToString(cipher: cipher).jsonDecode() as! [String: Any],
            let viewerId = decrypted["userId"] as? Int,
            let name = decrypted["name"] as? String,
            let photoUrl = decrypted["photoUrl"] as? String,
            let admin = decrypted["admin"] as? Bool
        else {
            socket.close()

            return
        }

        let member = addMemberIfNotExists(
            id: viewerId,
            name: name,
            photoUrl: photoUrl,
            admin: admin
        )

        let socketId = member.append(socket: socket)

        sendTopic(socket: socket)

        work(socketId: socketId, member: member, request: request, socket: socket)
    }

    func resetTopic() {
        self.topic = nil

        let message = [
            "topic": [
                "text": ""
            ]
        ]

        for (_, emember) in self.members {
            emember.sendStringMessage(string: try! message.jsonEncodedString(), final: true, completion: {})
        }
    }

    func sendTopic(socket: WebSocket) {
        guard self.topic != nil else {
            return
        }

        let message: [String : [String : String]] = [
            "topic": [
                "text": self.topic!
            ]
        ]

        socket.sendStringMessage(string: try! message.jsonEncodedString(), final: true, completion: {})
    }

    func work(socketId: Int, member: ChatMember, request: HTTPRequest, socket: WebSocket)
    {
        socket.readStringMessage {
            string, op, fin in

            guard let string = string else {
                print("Reason string = string")
                member.close(socketId: socketId)

                return
            }

            defer { self.work(socketId: socketId, member: member, request: request, socket: socket) }

            guard
                let inMessage = try? string.jsonDecode() as? [String : [String : String]],
                let body = inMessage?["sendMessage"]
            else {
                return
            }

            if (body["resetTopic"] != nil) {
                self.resetTopic()

                return
            }

            let msg = body["text"]
            let sticker = body["sticker"]
            let topic = member.admin ? body["topic"] : nil

            if msg == nil && sticker == nil && topic == nil {
                return
            }

            let message: [String : [String : Any]]

            if (topic != nil) {
                self.topic = topic

                message = [
                    "topic": [
                        "text": topic!
                    ]
                ]
            } else {
                message = [
                    "message": [
                        "userId": member.id,
                        "userName": member.name,
                        "userPic": member.photoUrl,
                        "text": msg ?? "",
                        "sticker": sticker ?? ""
                    ]
                ]
            }

            for (_, emember) in self.members {
                emember.sendStringMessage(string: try! message.jsonEncodedString(), final: true, completion: {})
            }
        }
    }
}