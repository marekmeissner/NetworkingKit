import Foundation

public struct HTTPResponse: Sendable {
  public let statusCode: Int
  public let headers: [String: String]
  public let data: Data

  public init(
    statusCode: Int,
    headers: [String: String] = [:],
    data: Data = Data()
  ) {
    self.statusCode = statusCode
    self.headers = headers
    self.data = data
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
