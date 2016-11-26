import PerfectLib
import PerfectWebSockets
import PerfectHTTP
import PerfectHTTPServer
import Foundation
import CryptoSwift

let server = HTTPServer()
var routes = Routes()


routes.add(method: .get, uri: "/", handler: {
    request, response in
    
//    guard let sign = request.param(name: "sign") else {
//        response.status = .badRequest
//        response.completed()
//        
//        return
//    }
//    
//    var signa = ""

//    for (key, value) in request.queryParams {
//        if key == "hash" || key == "sign" { continue }
//        signa += value
//    }
    
//    let x = try? HMAC(key: SECRET.utf8.map({$0}), variant: .sha256).authenticate(signa.utf8.map({$0}))
    
    let groupId: Int? =  Int(request.param(name: "group_id", defaultValue: "")!)
    
    guard groupId != nil && groupId! > 0 else {
        response.status = .badRequest
        response.completed()
        
        return
    }

    let viewerId: Int? =  Int(request.param(name: "viewer_id", defaultValue: "")!)

    guard viewerId != nil && viewerId! > 0 else {
        response.status = .badRequest
        response.completed()

        return
    }

    
    guard let apiResult = request.param(name: "api_result") else {
        response.status = .badRequest
        response.completed()
        
        return
    }
    
    guard let decoded = try? apiResult.jsonDecode() as? [String : Any] else {
        response.status = .badRequest
        response.completed()
        
        return
    }
    
    let script = "var socket = new WebSocket(\"ws://\" + location.host + \"/ws/\(groupId!)/\(viewerId!)\");"
            + "socket.onopen = function() {console.log(1); socket.send(\"Привет\");};"
            + "socket.onmessage = function(e) {console.log(event.data)};"
    
    response.setHeader(.contentType, value: "text/html")
    response.appendBody(string: "<html><head><title>Hello, world!</title></head><script>" + script + "</script><body></body></html>")
    response.completed()
  }
)

class ChatRoomHandler: WebSocketSessionHandler {
    let socketProtocol: String? = nil

    let groupId: Int
    var members: [Int : ChatMember] = [:]

    init(groupId: Int) {
        self.groupId = groupId
    }
    
    func handleSession(request: HTTPRequest, socket: WebSocket) {
        let viewerId: Int = Int(request.urlVariables["viewer_id"]!)!

        var member = members[viewerId]

        if member == nil {
            member = ChatMember(id: viewerId)

            member!.lastClose = {
                print("last close")
                self.members[viewerId] = nil
            }
            members[viewerId] = member
        }

        let socketId = member!.append(socket: socket)

        work(socketId: socketId, member: member!, request: request, socket: socket)
    }

    func work(socketId: Int, member: ChatMember, request: HTTPRequest, socket: WebSocket)
    {
        socket.readStringMessage {
            string, op, fin in

            guard socket.isConnected, let string = string else {
                member.close(socketId: socketId)

                return
            }

            print("Read msg: \(string) op: \(op) fin: \(fin)")

            for (_, emember) in self.members {
                print(emember.sockets.count)

                emember.sendStringMessage(string: string, final: true, completion: {})
            }

            self.work(socketId: socketId, member: member, request: request, socket: socket)
        }
    }
}

var rooms: [Int : ChatRoomHandler] = [:]

routes.add(method: .get, uri: "/ws/{group_id}/{viewer_id}", handler: {
    request, response in
    
    WebSocketHandler(handlerProducer: {
        (request: HTTPRequest, protocols: [String]) -> WebSocketSessionHandler? in
        
        guard let groupId = Int(request.urlVariables["group_id"] ?? "") else {
            return nil
        }

        guard let viewerId = Int(request.urlVariables["viewer_id"] ?? "") else {
            return nil
        }
        
        let room = rooms[groupId]
        
        if room == nil { rooms[groupId] = ChatRoomHandler(groupId: groupId) }
        
        return rooms[groupId]
    }).handleRequest(request: request, response: response)
    
})

server.addRoutes(routes)

configureServer(server)

do {
    try server.start()
} catch PerfectError.networkError(let err, let msg) {
    print("Network error thrown: \(err) \(msg)")
}

