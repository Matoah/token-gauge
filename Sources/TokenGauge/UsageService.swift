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
    /// 智谱AI 用量：请求头 Authorization: <API Key>
    func fetchUsage(config: ZhipuConfig, timeoutSeconds: Int) async throws -> UsageSummary {
        var request = try validatedRequest(urlString: config.baseURL, timeoutSeconds: timeoutSeconds)
        let key = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            request.setValue(key, forHTTPHeaderField: "Authorization")
        }
        let data = try await perform(request)
        let decoded = try JSONDecoder().decode(UsageResponse.self, from: data)
        guard decoded.success, decoded.code == 200 else {
            throw UsageError.apiError(decoded.msg ?? "未知错误")
        }
        return UsageSummary(limits: decoded.data?.limits ?? [])
    }

    /// DeepSeek 余额：请求头 Authorization: Bearer <API Key>
    func fetchBalance(config: DeepSeekConfig, timeoutSeconds: Int) async throws -> BalanceSummary {
        var request = try validatedRequest(urlString: config.baseURL, timeoutSeconds: timeoutSeconds)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let key = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        let data = try await perform(request)
        let decoded = try JSONDecoder().decode(BalanceResponse.self, from: data)
        guard let summary = BalanceSummary(from: decoded) else {
            throw UsageError.badResponse
        }
        return summary
    }

    /// 校验地址并构造 GET 请求
    private func validatedRequest(urlString: String, timeoutSeconds: Int) throws -> URLRequest {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme != nil, url.host != nil else {
            throw UsageError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = max(1, Double(timeoutSeconds))
        return request
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UsageError.badResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw UsageError.httpStatus(http.statusCode)
        }
        return data
    }
}
