import Foundation
import Testing

@testable import NetworkingKit

private class StubURLProtocol: URLProtocol, @unchecked Sendable {
  override class func canInit(with request: URLRequest) -> Bool { true }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let url = request.url else { return }
    if url.path == "/offline" {
      client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
      return
    }
    if url.path == "/cancelled" {
      client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
      return
    }
    if url.path == "/health" {
      guard
        let response = HTTPURLResponse(
          url: url, statusCode: 200, httpVersion: nil,
          headerFields: ["Content-Type": "application/json"]
        )
      else { return }
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: Data(#"{"status":"ok","database":"ok"}"#.utf8))
      client?.urlProtocolDidFinishLoading(self)
      return
    }
    let status = url.path == "/limited" ? 429 : 204
    guard
      let response = HTTPURLResponse(
        url: url, statusCode: status, httpVersion: nil, headerFields: ["Retry-After": "60"]
      )
    else { return }
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    if status == 429 {
      client?.urlProtocol(self, didLoad: Data("limited".utf8))
    }
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}

struct URLSessionHTTPClientTests {
  private struct Health: Decodable, Sendable {
    let status: String
    let database: String
  }

  private func makeClient() throws -> URLSessionHTTPClient {
    let settings: URLSessionConfiguration = URLSessionConfiguration.ephemeral
    settings.protocolClasses = [StubURLProtocol.self]
    return URLSessionHTTPClient(
      configuration: HTTPClientConfiguration(
        baseURL: try #require(URL(string: "https://example.com"))),
      session: URLSession(configuration: settings)
    )
  }

  @Test func sendsAndDecodesSuccessfulJSON() async throws {
    let health = try await makeClient().sendAndDecode(HTTPRequest(path: "health"), as: Health.self)

    #expect(health.status == "ok")
    #expect(health.database == "ok")
  }

  @Test func returnsEmptySuccess() async throws {
    let response = try await makeClient().send(HTTPRequest(path: "empty"))
    #expect(response.statusCode == 204)
    #expect(response.body.isEmpty)
  }

  @Test func preservesHTTPFailure() async throws {
    do {
      _ = try await makeClient().send(HTTPRequest(path: "limited"))
      Issue.record("Expected HTTP error")
    } catch HTTPError.unsuccessfulStatus(let response) {
      #expect(response.statusCode == 429)
      #expect(response.headers["Retry-After"] == "60")
      #expect(response.body == Data("limited".utf8))
    }
  }

  @Test func preservesTransportFailure() async throws {
    do {
      _ = try await makeClient().send(HTTPRequest(path: "offline"))
      Issue.record("Expected transport error")
    } catch HTTPError.transport(let error) {
      #expect((error as? URLError)?.code == .notConnectedToInternet)
    }
  }

  @Test func propagatesCancellation() async throws {
    let client = try makeClient()
    await #expect(throws: CancellationError.self) {
      try await client.send(HTTPRequest(path: "cancelled"))
    }
  }

  @Test func supportsConcurrentRequests() async throws {
    let client = try makeClient()
    try await withThrowingTaskGroup(of: Void.self) { group in
      for _ in 0..<10 {
        group.addTask {
          let response = try await client.send(HTTPRequest(path: "empty"))
          #expect(response.statusCode == 204)
        }
      }
      try await group.waitForAll()
    }
  }
}
