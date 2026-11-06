//
//  IntelligenceNotchViewModel.swift
//  Sapphire
//

#if !SAPPHIRE_FULL_BUILD
import Combine
import Foundation

final class IntelligenceNotchViewModel: ObservableObject {
    struct LogEntry: Identifiable {
        let id = UUID()
        var text: String
        var isError: Bool
        var isSubtask: Bool
    }

    struct RunResult {
        var success = false
        var subtasksCompleted = 0
        var subtasksTotal = 0
        var actionsTaken = 0
        var duration = 0.0
    }

    @Published var taskInput = ""
    @Published var isRunning = false
    @Published var statusMessage = "就绪"
    @Published var subtaskProgress: (current: Int, total: Int) = (0, 0)
    @Published var currentActionLabel = ""
    @Published var currentStepTitle = ""
    @Published var displayStepIndex = 0
    @Published var displayStepTotal = 0
    @Published var logEntries: [LogEntry] = []
    @Published var lastReply: String = ""
    @Published var lastResult: RunResult?

    private var activeTask: Task<Void, Never>?

    func run(apiKey: String, backend: LLMBackend, geminiSpeedMode: GeminiSpeedMode) {
        let prompt = taskInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        stop()
        let startedAt = Date()
        let resolvedBackend = backend.resolvedExecutionBackend(fallbackGeminiKey: apiKey)

        isRunning = true
        statusMessage = "正在通过 \(resolvedBackend.displayName) 思考…"
        currentStepTitle = "生成回答"
        displayStepIndex = 1
        displayStepTotal = 1
        subtaskProgress = (0, 1)
        logEntries.append(LogEntry(text: "提问：\(prompt)", isError: false, isSubtask: true))

        activeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let req = try LLMBackend.buildChatRequest(
                    prompt: prompt,
                    backend: resolvedBackend,
                    apiKey: apiKey,
                    geminiSpeedMode: geminiSpeedMode
                )
                let (data, response) = try await URLSession.shared.data(for: req)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    let body = String(data: data, encoding: .utf8) ?? ""
                    throw LLMBackendError.httpStatus(http.statusCode, body)
                }
                let answer = try LLMBackend.parseChatResponse(data: data, backend: resolvedBackend)
                self.lastReply = answer
                self.statusMessage = "已完成"
                self.subtaskProgress = (1, 1)
                self.logEntries.append(LogEntry(text: answer, isError: false, isSubtask: false))
                self.lastResult = RunResult(
                    success: true,
                    subtasksCompleted: 1,
                    subtasksTotal: 1,
                    actionsTaken: 1,
                    duration: Date().timeIntervalSince(startedAt)
                )
                MemorySystemManager.shared.recordInteraction(prompt: prompt, reply: answer)
            } catch {
                self.statusMessage = "请求未完成"
                self.logEntries.append(LogEntry(text: error.localizedDescription, isError: true, isSubtask: false))
                self.lastResult = RunResult(
                    success: false,
                    subtasksCompleted: 0,
                    subtasksTotal: 1,
                    actionsTaken: 0,
                    duration: Date().timeIntervalSince(startedAt)
                )
            }
            self.isRunning = false
        }
    }

    func stop() {
        activeTask?.cancel()
        activeTask = nil
        if isRunning {
            isRunning = false
            statusMessage = "已停止"
        }
    }
}
#endif
