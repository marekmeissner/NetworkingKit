import Foundation

public enum HTTPMethod: String, Sendable {
  case get = "GET"
  case post = "POST"
  case put = "PUT"
  case patch = "PATCH"
  case delete = "DELETE"
}

public struct HTTPRequest: Sendable {
  public let method: HTTPMethod
  public let path: String
  public let queryItems: [URLQueryItem]
  public let headers: [String: String]
  public let body: Data?

  public init(
    method: HTTPMethod = .get,
    path: String,
    queryItems: [URLQueryItem] = [],
    headers: [String: String] = [:],
    body: Data? = nil
  ) {
    self.method = method
    self.path = path
    self.queryItems = queryItems
    self.headers = headers
    self.body = body
  }

  public static func json<Body: Encodable>(
    method: HTTPMethod,
    path: String,
    body: Body,
    queryItems: [URLQueryItem] = [],
    headers: [String: String] = [:],
    encoder: JSONEncoder = JSONEncoder()
  ) throws -> HTTPRequest {
    var headers = headers.filter { $0.key.lowercased() != "content-type" }
    headers["Content-Type"] = "application/json"

    return try HTTPRequest(
      method: method, path: path, queryItems: queryItems, headers: headers,
      body: encoder.encode(body))
  }
}
