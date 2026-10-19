# NetworkingKit

- **Requests:** Supports GET, POST, PUT, PATCH, and DELETE, with query parameters, headers, and request bodies.
- **JSON:** Encode request bodies with `HTTPRequest.json` and decode responses with `sendAndDecode`.
- **Configuration:** Set a base URL, default headers, timeout, and an optional custom `URLSession`.
- **Responses:** Access the status code, headers, and raw body.
- **Errors:** Reports invalid requests, transport failures, non-2xx responses, and JSON decoding errors.
- **Cancellation:** Supports Swift task cancellation.

```swift
import Foundation
import NetworkingKit

struct User: Codable, Sendable {
    let name: String
}

let client = URLSessionHTTPClient(configuration: HTTPClientConfiguration(
    baseURL: URL(string: "https://example.com/api/")!
))

// GET /api/users/1 and decode JSON.
let user = try await client.sendAndDecode(
    HTTPRequest(path: "users/1"),
    as: User.self
)
print(user.name)

// POST a JSON body.
let request = try HTTPRequest.json(
    method: .post,
    path: "users",
    body: User(name: "Holden")
)
let response = try await client.send(request)
print(response.statusCode)
```
