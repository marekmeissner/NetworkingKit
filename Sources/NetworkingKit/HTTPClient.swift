import Foundation

public struct HTTPResponse: Sendable {
  public let statusCode: Int
  public let headers: [String: String]
  public let body: Data

  public init(
    statusCode: Int,
    headers: [String: String] = [:],
    body: Data = Data()
  ) {
    self.statusCode = statusCode
    self.headers = headers
    self.body = body
  }
}

public enum HTTPError: Error {
  case invalidRequest
  case invalidResponse
  case transport(any Error)
  case unsuccessfulStatus(HTTPResponse)
  case decoding(any Error)
}

public protocol HTTPClient: Sendable {
  func send(_ request: HTTPRequest) async throws -> HTTPResponse
}
