import PerfectLib
import PerfectWebSockets
import PerfectHTTP
import PerfectHTTPServer

let server = HTTPServer()
var routes = Routes()


configureServer(server)

do {
    try server.start()
} catch PerfectError.networkError(let err, let msg) {
    print("Network error thrown: \(err) \(msg)")
}

