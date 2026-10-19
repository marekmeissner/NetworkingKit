import Foundation
import Testing

@testable import NetworkingKit

private struct Message: Codable, Sendable, Equatable {
  let message: String
}

private struct StubClient: HTTPClient {
  let response: HTTPResponse

  func send(_ request: HTTPRequest) async throws -> HTTPResponse { response }
}

struct HTTPClientTests {
  @Test func buildsRequestPreservingBasePathAndEncodingQuery() throws {
    let client = URLSessionHTTPClient(
      configuration: HTTPClientConfiguration(
        baseURL: try #require(URL(string: "https://example.com/api/")),
        defaultHeaders: ["Authorization": "Bearer example base"],
        timeout: 30
      ))
    let request = try client.createURLRequest(
      HTTPRequest(
        path: "/users/id",
        queryItems: [URLQueryItem(name: "token", value: "t0ken")],
        headers: ["authorization": "Bearer example new"]
      ))
    let url = try #require(request.url)
    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

    #expect(components.path == "/api/users/id")
    #expect(components.queryItems == [URLQueryItem(name: "token", value: "t0ken")])
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer example new")
    #expect(request.timeoutInterval == 30)
  }

  @Test(arguments: ["../secret", "users/../secret", "https://other.com/path"])
  func rejectsUnsafePaths(path: String) throws {
    let client = URLSessionHTTPClient(
      configuration: HTTPClientConfiguration(
        baseURL: try #require(URL(string: "https://example.com"))
      ))
    #expect(throws: HTTPError.self) { try client.createURLRequest(HTTPRequest(path: path)) }
  }

  @Test func encodesAndDecodesJSON() async throws {
    let value = Message(message: "hello")
    let request = try HTTPRequest.json(method: .post, path: "message", body: value)
    #expect(request.headers["Content-Type"] == "application/json")
    let client = StubClient(
      response: HTTPResponse(statusCode: 200, body: try #require(request.body)))
    #expect(try await client.sendAndDecode(request, as: Message.self) == value)
  }

  @Test func acceptsEmptyResponseAndReportsMalformedJSON() async throws {
    let client = StubClient(response: HTTPResponse(statusCode: 204))
    let request = HTTPRequest(path: "logout")
    _ = try await client.send(request)
    await #expect(throws: HTTPError.self) {
      try await client.sendAndDecode(request, as: Message.self)
    }
  }
}
