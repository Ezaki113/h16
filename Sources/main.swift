import PerfectLib
import PerfectWebSockets
import PerfectHTTP
import PerfectHTTPServer
import Foundation
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

    guard
        let groupId =  Int(request.param(name: "group_id") ?? ""),
        let viewerId = Int(request.param(name: "viewer_id") ?? ""),
        let apiResult = request.param(name: "api_result"),
        let decoded = try? apiResult.jsonDecode() as? [String : Any],
        let decodedResponse = (decoded!["response"] as! [Any]).first as? [String: Any],
        let firstName = decodedResponse["first_name"] as? String,
        let lastName = decodedResponse["last_name"] as? String,
        let photoUrl = decodedResponse["photo_200"] as? String,
        let cipher: Blowfish = try? Blowfish(key: KEY, blockMode: .CBC, padding: PKCS7()),
        let hash: String = try? cipher.encrypt(
           try! [
               "userId": viewerId,
               "name": "\(firstName) \(lastName)",
               "photoUrl": photoUrl
           ].jsonEncodedString().utf8.map({$0})).toBase64()!
    else {
        response.status = .badRequest
        response.completed()

        return
    }

    var room = rooms[groupId]

    if room == nil {
        room = ChatRoomHandler(groupId: groupId)
        rooms[groupId] = room
    }

    let body = "<!DOCTYPE html><html class=\"h\"><head><meta http-equiv=\"Content-type\" content=\"text/html; charset=utf-8\"/>"
            + "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0, minimum-scale=1.0, maximum-scale=1.0, user-scalable=no\">"
            + "<script>window.hash = \"\(hash)\";</script>"
            + "<title></title><style>.h, .h body, .h {margin:0;padding:0;background: #FFF;height: 100%;}#root {position: relative;}</style><script src=\"//vk.com/js/api/xd_connection.js?2\"  type=\"text/javascript\"></script></head><body><div id=\"root\"></div><script type=\"text/javascript\" src=\"vendor.1480192578137.js\"></script><script type=\"text/javascript\" src=\"app.1480192578137.js\"></script></body></html>"

    response.setHeader(.contentType, value: "text/html")
    response.appendBody(string: body)
    response.completed()
  }
)

routes.add(method: .get, uri: "/ws/{group_id}/**", handler: {
    request, response in
    
    WebSocketHandler(handlerProducer: {
        (request: HTTPRequest, protocols: [String]) -> WebSocketSessionHandler? in
        
        guard let groupId = Int(request.urlVariables["group_id"] ?? "") else {
            return nil
        }

        guard let hash = request.urlVariables[routeTrailingWildcardKey]else {
            return nil
        }

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

