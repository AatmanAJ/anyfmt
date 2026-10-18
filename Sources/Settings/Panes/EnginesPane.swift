import AppKit
import SwiftUI
import HaloCore

struct EnginesPane: View {
    @ObservedObject var model: SettingsModel
    @State private var packs: [PackStatus] = []

    var body: some View {
        let engines = model.hooks.engineVersions()
        Form {
            Section {
                HStack(spacing: DesignTokens.Space.m) {
                    Image(systemName: "lock.laptopcomputer")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.accentText)
                        .frame(width: 36, height: 36)
                        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.iris.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Everything here runs on your Mac.")
                            .font(.system(size: DesignTokens.TypeRamp.body, weight: .semibold))
                        Text("These ship inside \(Brand.name), so it works with nothing else installed. Your files never leave your Mac.")
                            .font(.system(size: DesignTokens.TypeRamp.label))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 2)
            }

            Section {
                Grid(alignment: .leading, horizontalSpacing: DesignTokens.Space.l, verticalSpacing: 7) {
                    GridRow {
                        Text("Engine")
                        Text("Version")
                        Text("Licence")
                        Color.clear.frame(width: 1, height: 1).gridCellUnsizedAxes([.horizontal, .vertical])
                    }
                    .font(.system(size: DesignTokens.TypeRamp.caption, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    ForEach(engines) { engine in
                        GridRow {
                            Text(verbatim: engine.name)
                                .font(.system(size: DesignTokens.TypeRamp.body, weight: .medium))
                            Text(verbatim: engine.version)
                                .font(.system(size: DesignTokens.TypeRamp.label).monospacedDigit())
                                .foregroundStyle(.secondary)
                            Text(verbatim: engine.licence)
                                .font(.system(size: DesignTokens.TypeRamp.label))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .help(Text(verbatim: engine.licence))
                            Button {
                                BundledEngines.revealLicences(engine)
                            } label: {
                                Text("Licence…")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.accentText)
                            .font(.system(size: DesignTokens.TypeRamp.label, weight: .medium))
                            .gridColumnAlignment(.trailing)
                            .accessibilityLabel(Text("\(engine.name) licence"))
                        }
                    }
                }
                .padding(.vertical, DesignTokens.Space.xs)
                .accessibilityIdentifier("engines.table")
            } header: {
                HStack {
                    Text("Bundled engines")
                    Spacer()
                    Button("All Licences…") { BundledEngines.revealLicences() }
                        .controlSize(.small)
                        .accessibilityIdentifier("engines.allLicences")
                }
            } footer: {
                FootnoteText(text: String(localized: "Also uses macOS’s own \(BundledEngines.systemFrameworks.joined(separator: ", ")). Sources for every bundled engine are linked from each release."))
            }

            Section {
                if packs.isEmpty {
                    Text("No optional packs are offered in this build.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(packs) { pack in
                        PackRow(pack: pack, refresh: refresh)
                    }
                }
            } header: {
                Text("Optional packs")
            } footer: {
                FootnoteText(text: String(localized: "Packs are never downloaded unless you press Install. They run on your Mac like everything else."))
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: refresh)
        .task {
            // While a pack is busy, follow its progress.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if packs.contains(where: { $0.progress != nil }) { refresh() }
            }
        }
    }

    private func refresh() {
        packs = model.hooks.packs()
    }
}

private struct PackRow: View {
    let pack: PackStatus
    let refresh: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Space.m) {
            Image(systemName: pack.installed ? "shippingbox.fill" : "shippingbox")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(pack.installed ? Color.haloSuccess : Color.iris)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(verbatim: pack.name).font(.system(size: DesignTokens.TypeRamp.body, weight: .medium))
                    if pack.installed {
                        StatusBadge(tone: .good, text: String(localized: "Installed \(pack.version)"))
                    }
                }
                Text(verbatim: pack.summary)
                    .font(.system(size: DesignTokens.TypeRamp.label))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: detail)
                    .font(.system(size: DesignTokens.TypeRamp.caption))
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: DesignTokens.Space.s)
            if let p = pack.progress {
                ProgressView(value: p)
                    .frame(width: 90)
            } else if pack.installed {
                Button("Remove") { pack.remove(); refresh() }
                    .accessibilityIdentifier("engines.pack.\(pack.id).remove")
            } else {
                Button("Install") { pack.install(); refresh() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.iris)
                    .accessibilityIdentifier("engines.pack.\(pack.id).install")
            }
        }
        .padding(.vertical, 2)
    }

    private var detail: String {
        let size = ByteCountFormatter.string(fromByteCount: pack.downloadBytes, countStyle: .file)
        return pack.installed
            ? String(localized: "\(pack.licence) · \(size) on disk")
            : String(localized: "This downloads \(size) from \(pack.host) · \(pack.licence)")
    }
}
