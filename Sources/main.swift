import PerfectLib
import PerfectWebSockets
import PerfectHTTP
import PerfectHTTPServer
import CryptoSwift

let server = HTTPServer()
var routes = Routes()


let KEY = "Rqhweg12u387jGHhasd621t".utf8.map({$0})

var rooms: [Int : ChatRoomHandler] = [:]

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

    guard let viewerId = Int(request.param(name: "viewer_id")!),
          viewerId > 0,
        let apiResult = request.param(name: "api_result"),
        let decoded = try? apiResult.jsonDecode() as? [String : Any],
        let decodedResponse = (decoded!["response"] as! [Any]).first as? [String: Any],
        let firstName = decodedResponse["first_name"] as? String,
        let lastName = decodedResponse["last_name"] as? String,
        let photoUrl = decodedResponse["photo_200"] as? String else {
        response.status = .badRequest
        response.completed()

        return
    }

    let cookie = try! [
        "userId": viewerId,
        "name": "\(firstName) \(lastName)",
        "photoUrl": photoUrl
    ].jsonEncodedString()

    let encryptedCookie = try! Blowfish(key: KEY, blockMode: .CBC, padding: PKCS7())
            .encrypt(cookie.utf8.map({$0}))
            .toHexString()

    response.addCookie(HTTPCookie(
        name: "session",
        value: encryptedCookie,
        secure: true
    ))

    var room = rooms[groupId!]

    if room == nil {
        room = ChatRoomHandler(groupId: groupId!)
        rooms[groupId!] = room
    }

    room!.addMemberIfNotExists(id: viewerId, name: "\(firstName) \(lastName)", photoUrl: photoUrl)

//    let script = "var socket = new WebSocket(\"ws://\" + location.host + \"/ws/\(groupId!)/\(viewerId)\");"
//            + "socket.onopen = function() {console.log(1); socket.send(JSON.stringify({\"sendMessage\":{\"text\":\"kokoko\"}}));};"
//            + "socket.onmessage = function(e) {console.log(event.data)};"
    
    response.setHeader(.contentType, value: "text/html")

    let body = "<!DOCTYPE html><html class=\"h\"><head><meta http-equiv=\"Content-type\" content=\"text/html; charset=utf-8\"/><meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0, minimum-scale=1.0, maximum-scale=1.0, user-scalable=no\"><title></title><style>.h, .h body, .h {margin:0;padding:0;background: #FFF;height: 100%;}#root {position: relative;}</style><script src=\"//vk.com/js/api/xd_connection.js?2\"  type=\"text/javascript\"></script></head><body><div id=\"root\"></div><script type=\"text/javascript\" src=\"vendor.1480174273140.js\"></script><script type=\"text/javascript\" src=\"app.1480174273140.js\"></script></body></html>"

    response.appendBody(string: body)

//    response.appendBody(string: "<html><head><title>Hello, world!</title></head><script>" + script + "</script><body></body></html>")
    response.completed()
  }
)

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

        return rooms[groupId]!
    }).handleRequest(request: request, response: response)
    
})

server.addRoutes(routes)

configureServer(server)

do {
    try server.start()
} catch PerfectError.networkError(let err, let msg) {
    print("Network error thrown: \(err) \(msg)")
}

