import PerfectLib
import PerfectWebSockets
import PerfectHTTP
import PerfectHTTPServer

let server = HTTPServer()
var routes = Routes()


configureServer(server)

// Static

let documentRoot = "./Web"

let staticFileHandler = StaticFileHandler(documentRoot: documentRoot)


routes.add(method: .get, uri: "*", handler: { request, response in
    staticFileHandler.handleRequest(request: request, response: response)
})

do {
    try server.start()
} catch PerfectError.networkError(let err, let msg) {
    print("Network error thrown: \(err) \(msg)")
}

