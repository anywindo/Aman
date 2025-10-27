//
//  NetworkSecurityViewModel.swift
//  Aman
//
//  Simplified view model driving the Network Security dashboard.
//

import Foundation

@MainActor
final class NetworkSecurityViewModel: ObservableObject {
    @Published private(set) var internetResults: [InternetSecurityCheckResult.Kind: InternetSecurityCheckResult] = [:]
    @Published private(set) var internetRunningChecks: Set<InternetSecurityCheckResult.Kind> = []
    @Published private(set) var isInternetSuiteRunning = false
    @Published private(set) var internetLastError: String?

    private let toolkit: InternetSecurityToolkit
    private var internetSuiteTask: Task<Void, Never>?
    private var internetCheckTasks: [InternetSecurityCheckResult.Kind: Task<Void, Never>] = [:]

    init(toolkit: InternetSecurityToolkit = InternetSecurityToolkit()) {
        self.toolkit = toolkit
    }

    func runInternetSuite() {
        guard !isInternetSuiteRunning else { return }
        internetSuiteTask?.cancel()
        cancelIndividualTasks()

        internetSuiteTask = Task { [weak self] in
            await self?.executeInternetSuite()
        }
    }

    func runInternetCheck(_ kind: InternetSecurityCheckResult.Kind) {
        guard !internetRunningChecks.contains(kind) else { return }
        internetCheckTasks[kind]?.cancel()

        internetCheckTasks[kind] = Task { [weak self] in
            await self?.executeInternetCheck(kind: kind)
        }
    }

    func internetResult(for kind: InternetSecurityCheckResult.Kind) -> InternetSecurityCheckResult? {
        internetResults[kind]
    }

    @MainActor
    private func cancelIndividualTasks() {
        internetCheckTasks.values.forEach { $0.cancel() }
        internetCheckTasks.removeAll()
    }

    @MainActor
    private func executeInternetSuite() async {
        isInternetSuiteRunning = true
        internetLastError = nil
        internetRunningChecks = Set(InternetSecurityCheckResult.Kind.allCases)

        let results = await toolkit.runAllChecks()
        internetResults = Dictionary(uniqueKeysWithValues: results.map { ($0.kind, $0) })

        isInternetSuiteRunning = false
        internetRunningChecks.removeAll()
        internetSuiteTask = nil
    }

    @MainActor
    private func executeInternetCheck(kind: InternetSecurityCheckResult.Kind) async {
        internetRunningChecks.insert(kind)
        internetLastError = nil

        let result = await toolkit.run(kind: kind)
        internetResults[kind] = result

        internetRunningChecks.remove(kind)
        internetCheckTasks[kind] = nil
    }
}
