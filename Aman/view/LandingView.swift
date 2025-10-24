//
//  LandingView.swift
//  Aman
//
//  Created by Arwindo Pratama
//

import SwiftUI

struct LandingView: View {
    let startAudit: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 72, weight: .regular))
                .foregroundStyle(.tint)
            VStack(spacing: 8) {
                Text("Secure with Aman")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                Text("Run a security audit to align your Mac with best practices.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 12) {
                Button(action: startAudit) {
                    Label("Start Full Audit", systemImage: "play.circle.fill")
                        .font(.title3)
                        .padding(.horizontal, 32)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Text("Audits run with standard user privileges and never modify system settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(.regularMaterial)
        .textSelection(.enabled)
    }
}

#Preview {
    LandingView(startAudit: {})
        .frame(width: 600, height: 400)
}
