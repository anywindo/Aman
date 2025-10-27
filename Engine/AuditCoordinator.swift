//
//  AuditCoordinator.swift
//  Aman
//
//  Created by Codex.
//

import Foundation

@MainActor
final class AuditCoordinator: ObservableObject {
    @Published private(set) var findings: [AuditFinding] = []
    @Published private(set) var progress: Double = 0
    @Published private(set) var isRunning: Bool = false

    let availableModuleCount: Int

    private let registry = CheckRegistry()
    private let timeoutSeconds: TimeInterval
    private var runningTask: Task<Void, Never>?

    init(timeoutSeconds: TimeInterval = 15) {
        self.timeoutSeconds = timeoutSeconds
        self.availableModuleCount = registry.inventoryCount()
    }

    func start(domain: AuditDomain?) {
        guard !isRunning else { return }

        cancelIfNeeded()
        findings.removeAll()
        progress = 0
        isRunning = true

        let modules = registry.checks(matching: domain)
        let total = max(modules.count, 1)

        // Run on the MainActor (no detached task), avoiding capturing a main-actor 'self' in a @Sendable context.
        runningTask = Task(priority: .userInitiated) { [timeoutSeconds] in
            var completed = 0

            for check in modules {
                if Task.isCancelled { break }

                // Heavy work happens off-main inside AuditExecutor
                let finding = AuditExecutor.evaluate(check: check, timeout: timeoutSeconds)
                completed += 1

                // Update main-actor state
                self.findings.append(finding)
                self.progress = Double(completed) / Double(total)
            }

            // Finalize
            self.isRunning = false
            if Task.isCancelled {
                self.findings.removeAll()
                self.progress = 0
            }
        }
    }

    func reset() {
        cancelIfNeeded()
        findings.removeAll()
        progress = 0
        isRunning = false
    }

    private func cancelIfNeeded() {
        runningTask?.cancel()
        runningTask = nil
    }
}

// MARK: - Registry & Execution Helpers

private struct CheckRegistry {
    private static let domainCatalogs: [ObjectIdentifier: [String]] = [
        ObjectIdentifier(AdminPasswordForSecureSettingsCheck.self): ["Accounts"],
        ObjectIdentifier(AirDropDisabledCheck.self): ["Network"],
        ObjectIdentifier(AirDropInterfacePolicyCheck.self): ["Network"],
        ObjectIdentifier(AirPlayReceiverDisabledCheck.self): ["Network"],
        ObjectIdentifier(AirPlayServiceCheck.self): ["Network"],
        ObjectIdentifier(HttpServerCheck.self): ["Network"],
        ObjectIdentifier(AppTrackingTransparencyCheck.self): ["Privacy"],
        ObjectIdentifier(BluetoothMenuIconVisibleCheck.self): ["Network"],
        ObjectIdentifier(BluetoothSharingDisabledCheck.self): ["Network"],
        ObjectIdentifier(BluetoothSharingGranularCheck.self): ["Network"],
        ObjectIdentifier(ExternalIntelligenceDisableCheck.self): ["Security"],
        ObjectIdentifier(ExternalIntelligenceSignInDisableCheck.self): ["Security"],
        ObjectIdentifier(BridgeOSCompanionUpdateCheck.self): ["Network"],
        ObjectIdentifier(BonjourCheck.self): ["Network"],
        ObjectIdentifier(CredentialFlowsCheck.self): ["Accounts"],
        ObjectIdentifier(ContentCachingDisabledCheck.self): ["Network"],
        ObjectIdentifier(ContinuityFeaturesCheck.self): ["Network"],
        ObjectIdentifier(DiagnosticDataCheck.self): ["Privacy"],
        ObjectIdentifier(FirewallCheck.self): ["Network"],
        ObjectIdentifier(FirewallStealthModeCheck.self): ["Network"],
        ObjectIdentifier(FileSharingDisabledCheck.self): ["Network"],
        ObjectIdentifier(GuestConnectCheck.self): ["Network"],
        ObjectIdentifier(GuestLoginCheck.self): ["Accounts"],
        ObjectIdentifier(InternetSharingDisabledCheck.self): ["Network"],
        ObjectIdentifier(NfsServerCheck.self): ["Network"],
        ObjectIdentifier(LimitAdTrackingCheck.self): ["Privacy"],
        ObjectIdentifier(LocationServicesCheck.self): ["Privacy"],
        ObjectIdentifier(LocationServicesMenuIconCheck.self): ["Privacy"],
        ObjectIdentifier(LoginWindowPolicyCheck.self): ["Accounts"],
        ObjectIdentifier(PasswordHintsCheck.self): ["Accounts"],
        ObjectIdentifier(PasswordOnWakeCheck.self): ["Accounts"],
        ObjectIdentifier(PasswordPolicyCheck.self): ["Accounts"],
        ObjectIdentifier(MediaSharingDisabledCheck.self): ["Network"],
        ObjectIdentifier(PortListeningInventoryCheck.self): ["Network"],
        ObjectIdentifier(PortScannerCheck.self): ["Network"],
        ObjectIdentifier(IntranetSecurityCVECheck.self): ["Network", "Security"],
        ObjectIdentifier(PrinterSharingDisabledCheck.self): ["Network"],
        ObjectIdentifier(RemoteLoginDisabledCheck.self): ["Network"],
        ObjectIdentifier(RemoteManagementDisabledCheck.self): ["Network"],
        ObjectIdentifier(SafariInternetPluginsCheck.self): ["Privacy"],
        ObjectIdentifier(SafariSafeFilesCheck.self): ["Privacy"],
        ObjectIdentifier(SecureTokenStatusCheck.self): ["Accounts"],
        ObjectIdentifier(SensitiveLogAuditingCheck.self): ["Privacy"],
        ObjectIdentifier(PamSuSmartcardEnforceCheck.self): ["Accounts", "Security"],
        ObjectIdentifier(PamSudoSmartcardEnforceCheck.self): ["Accounts", "Security"],
        ObjectIdentifier(PasswordAlphanumericRequirementCheck.self): ["Accounts"],
        ObjectIdentifier(PasswordCustomRegexRequirementCheck.self): ["Accounts"],
        ObjectIdentifier(PasswordSimpleSequenceRestrictionCheck.self): ["Accounts"],
        ObjectIdentifier(PasswordSpecialCharacterRequirementCheck.self): ["Accounts"],
        ObjectIdentifier(SmartcardAllowCheck.self): ["Accounts"],
        ObjectIdentifier(SmartcardEnforcementCheck.self): ["Accounts"],
        ObjectIdentifier(SiriEnabledCheck.self): ["Privacy"],
        ObjectIdentifier(SshConfigHardeningCheck.self): ["Network"],
        ObjectIdentifier(SSHCheck.self): ["Network"],
        ObjectIdentifier(TemporaryGuestSessionCheck.self): ["Accounts"],
        ObjectIdentifier(UniversalControlCheck.self): ["Network"],
        ObjectIdentifier(HotCornersDisabledCheck.self): ["Security"],
        ObjectIdentifier(WakeForNetworkAccessCheck.self): ["Network"],
        ObjectIdentifier(WifiMenuIconVisibleCheck.self): ["Network"]
    ]

    private static let cmmcCatalogs: [Int32: [String]] = [
        3: ["CMMC Level 1"],
        6: ["CMMC Level 1", "CMMC Level 2"],
        9: ["CMMC Level 1"],
        10: ["CMMC Level 1"],
        12: ["CMMC Level 1"],
        13: ["CMMC Level 1"],
        18: ["CMMC Level 1"],
        20: ["CMMC Level 1", "CMMC Level 2"],
        22: ["CMMC Level 2"],
        24: ["CMMC Level 1"],
        30: ["CMMC Level 2"],
        31: ["CMMC Level 1"],
        37: ["CMMC Level 2"],
        38: ["CMMC Level 2"],
        39: ["CMMC Level 2"],
        41: ["CMMC Level 1", "CMMC Level 2"],
        42: ["CMMC Level 2"],
        43: ["CMMC Level 1"],
        44: ["CMMC Level 1", "CMMC Level 2"],
        50: ["CMMC Level 2"],
        57: ["CMMC Level 2"],
        58: ["CMMC Level 2"],
        59: ["CMMC Level 2"],
        102: ["CMMC Level 1"],
        104: ["CMMC Level 1"],
        105: ["CMMC Level 1"],
        106: ["CMMC Level 2"],
        108: ["CMMC Level 2"],
        209: ["CMMC Level 2"],
        205: ["CMMC Level 1"],
        206: ["CMMC Level 1"],
        208: ["CMMC Level 1"],
        212: ["CMMC Level 1"],
        213: ["CMMC Level 1"],
        214: ["CMMC Level 1"],
        215: ["CMMC Level 2"],
        216: ["CMMC Level 2"],
        217: ["CMMC Level 1", "CMMC Level 2"],
        218: ["CMMC Level 1", "CMMC Level 2"],
        219: ["CMMC Level 1", "CMMC Level 2"],
        220: ["CMMC Level 1", "CMMC Level 2"],
        221: ["CMMC Level 2"],
        222: ["CMMC Level 2"],
        223: ["CMMC Level 2"],
        224: ["CMMC Level 2"],
        225: ["CMMC Level 2"],
        226: ["CMMC Level 2"],
        227: ["CMMC Level 2"]
    ]

    func inventoryCount() -> Int {
        checks(matching: nil).count
    }

    func checks(matching domain: AuditDomain?) -> [SystemCheck] {
        var inventory: [SystemCheck] = []
        inventory.reserveCapacity(64)

        inventory.append(contentsOf: securitySuite())
        inventory.append(contentsOf: accountSuite())
        inventory.append(contentsOf: privacySuite())
        inventory.append(contentsOf: networkingSuite())

        guard let domain, domain != .all else {
            return inventory
        }

        return inventory.filter { $0.categories.contains(where: { $0 == domain.title }) }
    }

    private func securitySuite() -> [SystemCheck] {
        let checks: [SystemCheck] = [
            GatekeeperBypassCheck(),
            FileVaultCheck(),
            SIPStatusCheck(),
            FirewallCheck(),
            CertificateTrustCheck(),
            SSHCheck(),
            iCloudDriveCheck(),
            GuestLoginCheck(),
            SiriEnabledCheck(),
            SecureKernelExtensionLoadingCheck(),
            DiagnosticDataCheck(),
            Java6Check(),
            EFIVersionCheck(),
            BonjourCheck(),
            HttpServerCheck(),
            NfsServerCheck(),
            PasswordHintsCheck(),
            GuestConnectCheck(),
            SafariSafeFilesCheck(),
            SafariInternetPluginsCheck(),
            FilenameExtensionsCheck(),
            AppleSoftwareUpdateCheck(),
            AutomaticSoftwareUpdateCheck(),
            AppStoreUpdatesCheck(),
            SecurityUpdatesCheck(),
            CriticalUpdateInstallCheck(),
            SoftwareUpdateDeferralCheck(),
            FirewallStealthModeCheck(),
            AirDropDisabledCheck(),
            SetTimeAndDateAutomaticallyEnabledCheck(),
            TimeWithinLimitsCheck(),
            DVDOrCDSharingDisabledCheck(),
            ScreenSharingDisabledCheck(),
            FileSharingDisabledCheck(),
            PrinterSharingDisabledCheck(),
            RemoteLoginDisabledCheck(),
            RemoteManagementDisabledCheck(),
            InternetSharingDisabledCheck(),
            ContentCachingDisabledCheck(),
            MediaSharingDisabledCheck(),
            BluetoothSharingDisabledCheck(),
            TimeMachineEnabledCheck(),
            LocationServicesCheck(),
            LimitAdTrackingCheck(),
            UniversalControlCheck(),
            WakeForNetworkAccessCheck(),
            ScreenSaverInactivityCheck(),
            PasswordOnWakeCheck(),
            SecurityAuditingCheck(),
            LockdownModeCheck(),
            ContinuityFeaturesCheck(),
            BridgeOSCompanionUpdateCheck(),
            ExternalIntelligenceDisableCheck(),
            ExternalIntelligenceSignInDisableCheck(),
            PamSuSmartcardEnforceCheck(),
            PamSudoSmartcardEnforceCheck(),
            HotCornersDisabledCheck()
        ]
        tagAll(checks, categories: ["Security"])
        applyDomainCatalogs(checks)
        applyBenchmarkCatalogs(checks)
        return checks
    }

    private func accountSuite() -> [SystemCheck] {
        let checks: [SystemCheck] = [
            SecureTokenStatusCheck(),
            AdminPasswordForSecureSettingsCheck(),
            CredentialFlowsCheck(),
            SmartcardAllowCheck(),
            SmartcardEnforcementCheck(),
            PasswordAlphanumericRequirementCheck(),
            PasswordCustomRegexRequirementCheck(),
            PasswordSimpleSequenceRestrictionCheck(),
            PasswordSpecialCharacterRequirementCheck()
        ]
        tagAll(checks, categories: ["Security", "Accounts"])
        applyDomainCatalogs(checks)
        applyBenchmarkCatalogs(checks)
        return checks
    }

    private func privacySuite() -> [SystemCheck] {
        let checks: [SystemCheck] = [
            AppTrackingTransparencyCheck(),
            SensitiveLogAuditingCheck()
        ]
        tagAll(checks, categories: ["Privacy"])
        applyDomainCatalogs(checks)
        applyBenchmarkCatalogs(checks)
        return checks
    }

    private func networkingSuite() -> [SystemCheck] {
        let checks: [SystemCheck] = [
            PortListeningInventoryCheck(),
            PortScannerCheck(),
            IntranetSecurityCVECheck()
        ]
        tagAll(checks, categories: ["Security", "Network"])
        applyDomainCatalogs(checks)
        applyBenchmarkCatalogs(checks)
        return checks
    }

    private func tagAll(_ checks: [SystemCheck], categories: [String]) {
        guard !categories.isEmpty else { return }
        checks.forEach { $0.appendCategories(categories) }
    }

    private func applyDomainCatalogs(_ checks: [SystemCheck]) {
        for check in checks {
            let identifier = ObjectIdentifier(type(of: check))
            if let extras = Self.domainCatalogs[identifier] {
                check.appendCategories(extras)
            }
        }
    }

    private func applyBenchmarkCatalogs(_ checks: [SystemCheck]) {
        for check in checks {
            let docID = check.docID
            if let extras = Self.cmmcCatalogs[docID] {
                check.appendBenchmarks(extras)
            }
        }
    }
}

private enum AuditExecutor {
    static func evaluate(check: SystemCheck, timeout: TimeInterval) -> AuditFinding {
        check.prepareForExecution()

        let semaphore = DispatchSemaphore(value: 0)
        var finding: AuditFinding?
        let queue = DispatchQueue(label: "com.arwindo.aman.check.\(check.docID)", qos: .userInitiated)

        queue.async {
            check.evaluate()
            finding = check.makeFinding(timedOut: false, timeoutDescription: nil)
            semaphore.signal()
        }

        let waitResult = semaphore.wait(timeout: .now() + timeout)
        let timedOut = waitResult == .timedOut

        if timedOut {
            let timeoutMessage = "Check timed out after \(Int(timeout)) seconds."
            if check.checkstatus == nil {
                check.checkstatus = "Yellow"
            }
            if check.status == nil || check.status?.isEmpty == true {
                check.status = timeoutMessage
            }
            return check.makeFinding(timedOut: true, timeoutDescription: timeoutMessage)
        }

        return finding ?? check.makeFinding(timedOut: false, timeoutDescription: nil)
    }
}
