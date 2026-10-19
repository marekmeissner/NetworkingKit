import Foundation

public struct HTTPClientConfiguration: Sendable {
  public let baseURL: URL
  public let defaultHeaders: [String: String]
  public let timeout: TimeInterval

  public init(baseURL: URL, defaultHeaders: [String: String] = [:], timeout: TimeInterval = 60) {
    self.baseURL = baseURL
    self.defaultHeaders = defaultHeaders
    self.timeout = timeout
  }
}

public struct URLSessionHTTPClient: HTTPClient {
  private let configuration: HTTPClientConfiguration
  private let session: URLSession

  public init(configuration: HTTPClientConfiguration, session: URLSession? = nil) {
    self.configuration = configuration
    if let session {
      self.session = session
    } else {
      let sessionConfig = URLSessionConfiguration.ephemeral
      sessionConfig.urlCache = nil
      sessionConfig.httpCookieStorage = nil
      sessionConfig.urlCredentialStorage = nil
      sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
      self.session = URLSession(configuration: sessionConfig)
    }
  }

  public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
    try Task.checkCancellation()

    let urlRequest = try createURLRequest(request)
    let data: Data
    let response: URLResponse

    do {
      (data, response) = try await session.data(for: urlRequest)
    } catch {
      if Task.isCancelled || (error as? URLError)?.code == .cancelled {
        throw CancellationError()
      }
      throw HTTPError.transport(error)
    }

    try Task.checkCancellation()

    guard let response = response as? HTTPURLResponse else {
      throw HTTPError.invalidResponse
    }

    var headers: [String: String] = [:]
    for (key, value) in response.allHeaderFields {
      headers[String(describing: key)] = String(describing: value)
    }
    let result = HTTPResponse(statusCode: response.statusCode, headers: headers, body: data)

    guard (200..<300).contains(result.statusCode) else {
      throw HTTPError.unsuccessfulStatus(result)
    }

    return result
  }

  func createURLRequest(_ request: HTTPRequest) throws -> URLRequest {
    guard
      var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false),
      ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
      components.host != nil,
      components.user == nil, components.password == nil,
      components.fragment == nil, components.query == nil,
      configuration.timeout.isFinite, configuration.timeout > 0,
      !request.path.contains("://"),
      !request.path.split(separator: "/").contains(where: { $0 == "." || $0 == ".." })
    else {
      throw HTTPError.invalidRequest
    }

    let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let path = request.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

    components.path = "/" + [basePath, path].filter({ !$0.isEmpty }).joined(separator: "/")
    components.queryItems = request.queryItems.isEmpty ? nil : request.queryItems

    guard let url = components.url else { throw HTTPError.invalidRequest }

    var result = URLRequest(url: url, timeoutInterval: configuration.timeout)

    result.httpMethod = request.method.rawValue

    for (name, value) in configuration.defaultHeaders {
      result.setValue(value, forHTTPHeaderField: name)
    }

    for (name, value) in request.headers {
      result.setValue(value, forHTTPHeaderField: name)
    }

    result.httpBody = request.body

    return result
  }
}
