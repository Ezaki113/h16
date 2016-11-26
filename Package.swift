import PackageDescription

let package = Package(
    name: "h16",
    dependencies: [
        .Package(url:"https://github.com/PerfectlySoft/Perfect-WebSockets.git", majorVersion: 2, minor: 0),
        .Package(url: "https://github.com/PerfectlySoft/Perfect-HTTPServer.git", majorVersion: 2, minor: 0)
    ]
)
