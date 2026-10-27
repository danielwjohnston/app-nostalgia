import Foundation
import AppKit

struct OllamaConfig: Codable {
    var host: String = "http://localhost:11434"
    var apiKey: String = ""
    var model: String = "qwen2.5-coder:3b"
    var opItem: String = "Ollama"
}

@MainActor
final class OllamaService {
    static let shared = OllamaService()

    private(set) var config: OllamaConfig
    private let configFileURL: URL

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.configFileURL = home.appendingPathComponent(".excite_messenger.json")
        var loaded = OllamaConfig()

        if let data = try? Data(contentsOf: configFileURL),
           let dec = try? JSONDecoder().decode(OllamaConfig.self, from: data) {
            loaded = dec
        }

        // Environment variable overrides
        if let envKey = ProcessInfo.processInfo.environment["OLLAMA_API_KEY"], !envKey.isEmpty {
            loaded.apiKey = envKey
        }
        if let envHost = ProcessInfo.processInfo.environment["OLLAMA_HOST"], !envHost.isEmpty {
            loaded.host = envHost
        }
        if let envModel = ProcessInfo.processInfo.environment["OLLAMA_MODEL"], !envModel.isEmpty {
            loaded.model = envModel
        }
        if let envOpItem = ProcessInfo.processInfo.environment["OLLAMA_OP_ITEM"], !envOpItem.isEmpty {
            loaded.opItem = envOpItem
        }

        self.config = loaded
        saveConfig()
    }

    func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            try? data.write(to: configFileURL)
        }
    }

    func updateSettings(host: String?, apiKey: String?, model: String?, opItem: String?) {
        if let h = host, !h.isEmpty { config.host = h.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let k = apiKey { config.apiKey = k.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let m = model, !m.isEmpty { config.model = m.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let op = opItem, !op.isEmpty { config.opItem = op.trimmingCharacters(in: .whitespacesAndNewlines) }
        saveConfig()
    }

    /// Attempts to read the Ollama API key from 1Password CLI `op`
    func fetchKeyFrom1Password(itemName: String? = nil) -> String? {
        let item = (itemName ?? config.opItem).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !item.isEmpty else { return nil }

        let opCandidates = [
            "/usr/local/bin/op",
            "/opt/homebrew/bin/op",
            "/usr/bin/op"
        ]
        guard let opPath = opCandidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            return nil
        }

        // 1. Direct op:// URI read (e.g. op://vault/item/credential or op://Personal/Ollama/password)
        if item.hasPrefix("op://") {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: opPath)
            proc.arguments = ["read", item]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = Pipe()
            do {
                try proc.run()
                proc.waitUntilExit()
                if proc.terminationStatus == 0 {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty {
                        config.apiKey = str
                        config.opItem = item
                        saveConfig()
                        return str
                    }
                }
            } catch {
                return nil
            }
            return nil
        }

        // 2. Structured JSON inspection with --reveal
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: opPath)
        proc.arguments = ["item", "get", item, "--format", "json", "--reveal"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()

        do {
            try proc.run()
            proc.waitUntilExit()
            if proc.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let fields = json["fields"] as? [[String: Any]] {

                    let preferred = ["api key", "apikey", "credential", "password", "token", "secret"]
                    for pref in preferred {
                        if let matched = fields.first(where: {
                            let label = (($0["label"] as? String) ?? "").lowercased()
                            let idStr = (($0["id"] as? String) ?? "").lowercased()
                            let val = (($0["value"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                            return (label == pref || idStr == pref) && !val.isEmpty
                        }), let val = matched["value"] as? String {
                            let trimmed = val.trimmingCharacters(in: .whitespacesAndNewlines)
                            config.apiKey = trimmed
                            config.opItem = item
                            saveConfig()
                            return trimmed
                        }
                    }

                    // Fallback to any concealed non-empty field
                    if let concealed = fields.first(where: {
                        let t = ($0["type"] as? String) ?? ""
                        let val = (($0["value"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        return (t == "CONCEALED" || t == "PASSWORD") && !val.isEmpty
                    }), let val = concealed["value"] as? String {
                        let trimmed = val.trimmingCharacters(in: .whitespacesAndNewlines)
                        config.apiKey = trimmed
                        config.opItem = item
                        saveConfig()
                        return trimmed
                    }
                }
            }
        } catch {
            // fallthrough to text fallback
        }

        // 3. Fallback to --fields query
        let procFallback = Process()
        procFallback.executableURL = URL(fileURLWithPath: opPath)
        procFallback.arguments = ["item", "get", item, "--fields", "label=credential,label=password,label=api key,label=token", "--reveal"]
        let pipeFallback = Pipe()
        procFallback.standardOutput = pipeFallback
        procFallback.standardError = Pipe()

        do {
            try procFallback.run()
            procFallback.waitUntilExit()
            if procFallback.terminationStatus == 0 {
                let data = pipeFallback.fileHandleForReading.readDataToEndOfFile()
                if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty {
                    config.apiKey = str
                    config.opItem = item
                    saveConfig()
                    return str
                }
            }
        } catch {
            return nil
        }

        return nil
    }

    /// Queries Ollama for available local/remote models
    func fetchAvailableModels() async -> [String] {
        guard let url = URL(string: "\(config.host)/api/tags") else { return [] }
        var req = URLRequest(url: url)
        req.timeoutInterval = 4.0
        if !config.apiKey.isEmpty {
            req.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
            req.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        }
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = json["models"] as? [[String: Any]] else {
            return []
        }
        return arr.compactMap { $0["name"] as? String }
    }

    /// Sends a prompt to Ollama /api/chat with persona instructions and chat history
    func generateReply(
        forHandle handle: String,
        buddyName: String,
        history: [ChatMessage],
        userMessage: String
    ) async throws -> String {
        let systemPrompt = personaPrompt(forHandle: handle, buddyName: buddyName)

        var messagesPayload: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]

        // Append recent chat context (up to last 6 messages)
        for msg in history.suffix(6) {
            let role = msg.isFromUser ? "user" : "assistant"
            messagesPayload.append(["role": role, "content": msg.text])
        }
        messagesPayload.append(["role": "user", "content": userMessage])

        let requestBody: [String: Any] = [
            "model": config.model,
            "messages": messagesPayload,
            "stream": false,
            "options": [
                "temperature": 0.7,
                "num_predict": 128
            ]
        ]

        guard let endpoint = URL(string: "\(config.host)/api/chat") else {
            throw URLError(.badURL)
        }

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !config.apiKey.isEmpty {
            req.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
            req.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        req.timeoutInterval = 30.0

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if http.statusCode != 200 {
            let errText = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw NSError(domain: "Ollama", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: errText])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messageObj = json["message"] as? [String: Any],
              let content = messageObj["content"] as? String else {
            throw NSError(domain: "Ollama", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Ollama response structure"])
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func personaPrompt(forHandle handle: String, buddyName: String) -> String {
        switch handle {
        case "swerndorfer@excite.com":
            return """
            You are Scott Werndorfer, lead software engineer of Excite Assistant and Excite Messenger at Excite@Home in September 1999.
            Personality: Enthusiastic, friendly, nostalgic Y2K dot-com engineer. You wrote TSlidingWins in VC++ 6.0 and MFC 4.2 using integer ease-out physics (sar ecx, 3) on Windows 98.
            Colleagues: Kevin Kurtz (UI & Region graphics) and C.J.klug (Architecture).
            Tone: Casual 1999 instant messaging style. Keep your response short and punchy (1 to 3 sentences).
            """

        case "kkurtz@excite.com":
            return """
            You are Kevin Kurtz, UI and graphic regions engineer for Excite Assistant at Excite@Home in 1999.
            Personality: Detail-oriented visual craftsman. You love pixel art, 3D beveled tactile buttons, chroma-keying pure blue (#0000FF), and carving scalloped tab curves using Constructive Solid Geometry CombineRgn(RGN_DIFF).
            Tone: Friendly, concise, authentic 1999 tech chat (1 to 3 sentences).
            """

        case "cjklug@excite.com":
            return """
            You are C.J.klug, systems and desktop architect at Excite@Home in 1999.
            Personality: Pragmatic, broadband cable enthusiast, music lover tuning into SomaFM on TuneIn Radio.
            Tone: Concise, informal 1999 instant message (1 to 3 sentences).
            """

        default:
            return """
            You are Excite Live Bot, a helpful and knowledgeable AI assistant integrated into Excite Messenger v2.0, powered by Ollama.
            Personality: Helpful, smart, polite, and aware of both vintage 1999 tech history and modern 2026 computing.
            Keep your answers concise and formatted for an instant messenger transcript (1 to 3 sentences).
            """
        }
    }
}
