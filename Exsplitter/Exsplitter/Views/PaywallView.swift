//
//  PaywallView.swift
//  BudgetSplitter
//
//  Subscription required for cloud mode. Replace with StoreKit purchase flow.
//

import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    var onSubscribe: (() -> Void)?
    var onRestore: (() -> Void)?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 28) {
                    Spacer()

                    Image(systemName: "cloud.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    VStack(spacing: 8) {
                        Text("Cloud Sync")
                            .font(.title.bold())
                            .foregroundColor(.white)
                        Text("Subscribe to sync your data across devices and access cloud backup.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        FeatureRow(icon: "icloud.fill", text: "Sync across all your devices")
                        FeatureRow(icon: "lock.shield.fill", text: "Secure cloud backup")
                        FeatureRow(icon: "person.3.fill", text: "Share trips with groups")
                    }
                    .padding(.vertical, 20)

                    Spacer()

                    VStack(spacing: 12) {
                        Button {
                            onSubscribe?()
                            dismiss()
                        } label: {
                            Text("Subscribe — $2.99/month")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                        }

                        Button {
                            onRestore?()
                        } label: {
                            Text("Restore Purchases")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Button("Maybe Later") {
                            dismiss()
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 28, alignment: .center)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    PaywallView(
        onSubscribe: { },
        onRestore: { }
    )
}
