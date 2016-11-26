import PerfectLib
import PerfectWebSockets
import PerfectHTTP
import PerfectHTTPServer

let server = HTTPServer()
var routes = Routes()

routes.add(method: .get, uri: "/", handler: {
    request, response in
    response.setHeader(.contentType, value: "text/html")
    response.appendBody(string: "<html><title>Hello, world!</title><body>Hello, world!</body></html>")
    response.completed()
  }
)

server.addRoutes(routes)

configureServer(server)

do {
    try server.start()
} catch PerfectError.networkError(let err, let msg) {
    print("Network error thrown: \(err) \(msg)")
}

