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
                Color.appBackground.ignoresSafeArea()

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
                        Text(L10n.string("paywall.title"))
                            .font(.title.bold())
                            .foregroundColor(.appPrimary)
                        Text(L10n.string("paywall.subtitle"))
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        FeatureRow(icon: "icloud.fill", text: L10n.string("paywall.featureSync"))
                        FeatureRow(icon: "lock.shield.fill", text: L10n.string("paywall.featureBackup"))
                        FeatureRow(icon: "person.3.fill", text: L10n.string("paywall.featureShare"))
                    }
                    .padding(.vertical, 20)

                    Spacer()

                    VStack(spacing: 12) {
                        Button {
                            onSubscribe?()
                            dismiss()
                        } label: {
                            Text(L10n.string("paywall.subscribeButton"))
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
                            Text(L10n.string("paywall.restorePurchases"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Button(L10n.string("paywall.maybeLater")) {
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
