import Foundation

enum UsageError: LocalizedError {
    case invalidURL
    case badResponse
    case httpStatus(Int)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "请求地址无效"
        case .badResponse:
            return "服务端返回了无法解析的数据"
        case .httpStatus(let code):
            return "服务端返回 HTTP \(code)"
        case .apiError(let msg):
            return "接口返回失败：\(msg)"
        }
    }
}

struct UsageService {
    func fetch(config: Config) async throws -> UsageSummary {
        let urlString = config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: urlString), url.scheme != nil, url.host != nil else {
            throw UsageError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = max(1, Double(config.timeoutSeconds))

        let key = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            request.setValue(key, forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UsageError.badResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw UsageError.httpStatus(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(UsageResponse.self, from: data)
        guard decoded.success, decoded.code == 200 else {
            throw UsageError.apiError(decoded.msg ?? "未知错误")
        }
        return UsageSummary(limits: decoded.data?.limits ?? [])
    }
}
