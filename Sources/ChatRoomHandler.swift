import PerfectLib
import PerfectWebSockets
import PerfectHTTP
import PerfectHTTPServer

class ChatRoomHandler: WebSocketSessionHandler {
    let socketProtocol: String? = nil

    let groupId: Int
    var members: [Int : ChatMember] = [:]

    init(groupId: Int) {
        self.groupId = groupId
    }

    func addMemberIfNotExists(id: Int, name: String, photoUrl: String)
    {
        var member = members[id]

        if member == nil {
            member = ChatMember(id: id, name: name, photoUrl: photoUrl)

            member!.lastClose = {
//                self.members[id] = nil
            }
            members[id] = member
        }
    }

    func handleSession(request: HTTPRequest, socket: WebSocket) {

        let viewerId: Int = Int(request.urlVariables["viewer_id"]!)!

        let member = members[viewerId]!
        let socketId = member.append(socket: socket)
        work(socketId: socketId, member: member, request: request, socket: socket)
    }

    func work(socketId: Int, member: ChatMember, request: HTTPRequest, socket: WebSocket)
    {
        socket.readStringMessage {
            string, op, fin in

            func skip() {
                self.work(socketId: socketId, member: member, request: request, socket: socket)
            }

            guard socket.isConnected else {
                print("Reason socked.isConnected")
                member.close(socketId: sockerId)

                return
            }

            guard let string = string else {
                print("Reason string = string")
                member.close(socketId: socketId)

                return
            }
            guard
                    let inMessage = try? string.jsonDecode() as? [String : [String : String]],
                    let body = inMessage?["sendMessage"]
            else {
                skip()

                return
            }

            let msg = body["text"]
            let sticker = body["sticker"]

            if msg == nil && sticker == nil {
                skip()

                return
            }

            let message: [String : [String: Any]] = [
                "message": [
                    "userId": member.id,
                    "userName": member.name,
                    "userPic": member.photoUrl,
                    "text": msg ?? "",
                    "sticker": sticker ?? ""
                ]
            ]

            for (_, emember) in self.members {
                emember.sendStringMessage(string: try! message.jsonEncodedString(), final: true, completion: {})
            }

            skip()
        }
    }
}