import SwiftUI

struct ContentView: View {
    @ObservedObject var coordinator: SubtitleCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                statusCard
                regionCard
                previewCard
                settingsCard
                privacyNote
            }
            .padding(24)
        }
        .frame(minWidth: 560, idealWidth: 610, minHeight: 650, idealHeight: 720)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "captions.bubble.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 3) {
                Text("双语字幕镜")
                    .font(.system(size: 25, weight: .bold))
                Text("识别屏幕原语言字幕，在原字幕下方叠加中文")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var statusCard: some View {
        Card {
            HStack(spacing: 12) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                    .shadow(color: statusColor.opacity(0.45), radius: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(coordinator.status.title)
                        .font(.headline)
                    if let detail = coordinator.status.detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if coordinator.isRunning {
                        Text("已处理 \(coordinator.processedFrameCount) 帧")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()

                if coordinator.status == .permissionRequired {
                    Button("打开系统设置") {
                        coordinator.openScreenRecordingSettings()
                    }
                } else if coordinator.isRunning {
                    Button("停止") { coordinator.stop() }
                        .keyboardShortcut(".", modifiers: .command)
                } else {
                    Button("开始生成字幕") { coordinator.start() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .keyboardShortcut(.return, modifiers: .command)
                }
            }
        }
    }

    private var regionCard: some View {
        Card(title: "字幕区域", systemImage: "viewfinder") {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    if let region = coordinator.region {
                        Text(region.description)
                            .font(.headline)
                        Text("全屏预设会避开 Apple TV 底部的片名和进度条。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("尚未选择区域")
                            .font(.headline)
                        Text("直接开始会自动使用 Apple TV 全屏预设，也可以手动框选。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 7) {
                    Button("Apple TV 全屏预设") {
                        coordinator.useAppleTVFullScreenPreset()
                    }
                    .controlSize(.large)

                    Button(coordinator.region == nil ? "手动框选…" : "重新手动框选…") {
                        coordinator.selectRegion()
                    }
                    .buttonStyle(.link)
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                }
            }
        }
    }

    private var previewCard: some View {
        Card(title: "实时预览", systemImage: "text.bubble") {
            VStack(alignment: .leading, spacing: 12) {
                subtitlePreview(label: "最近识别到的原文", text: coordinator.sourceText)
                Divider()
                subtitlePreview(label: "最近显示的中文", text: coordinator.translatedText)

                if let confidence = coordinator.confidence {
                    Text("OCR 置信度 \(Int(confidence * 100))%")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func subtitlePreview(label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text.isEmpty ? "等待字幕…" : text)
                .font(.system(size: 16, weight: text.isEmpty ? .regular : .medium))
                .foregroundStyle(text.isEmpty ? .tertiary : .primary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
        }
    }

    private var settingsCard: some View {
        Card(title: "识别与显示", systemImage: "slider.horizontal.3") {
            VStack(spacing: 14) {
                HStack {
                    Text("字幕原语言")
                    Spacer()
                    Picker("字幕原语言", selection: $coordinator.sourceLanguage) {
                        ForEach(SubtitleSourceLanguage.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }

                Divider()

                HStack {
                    Text("翻译成")
                    Spacer()
                    Picker("翻译成", selection: $coordinator.targetLanguage) {
                        ForEach(TranslationTarget.allCases) { target in
                            Text(target.title).tag(target)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }

                Divider()

                HStack {
                    Text("扫描速度")
                    Spacer()
                    Picker("扫描速度", selection: $coordinator.scanSpeed) {
                        ForEach(ScanSpeed.allCases) { speed in
                            Text(speed.title).tag(speed)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }

                Divider()

                HStack {
                    Text("字幕样式")
                    Spacer()
                    Picker("字幕样式", selection: $coordinator.stylePreset) {
                        ForEach(SubtitleStylePreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }

                Divider()

                HStack(spacing: 12) {
                    Text("字号")
                    Slider(value: $coordinator.subtitleScale, in: 0.75...1.50, step: 0.05)
                    Text("\(Int(coordinator.subtitleScale * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 42, alignment: .trailing)
                }

                Divider()

                Toggle("显示半透明黑色字幕底", isOn: $coordinator.subtitleBackgroundEnabled)

                Divider()

                Toggle("设置时显示字幕识别区域边框", isOn: $coordinator.showGuide)

                HStack {
                    Text("Apple TV 模式使用系统半粗体白字、紧凑深灰底和小圆角；仍看不清时可选高对比。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(coordinator.isShowingStylePreview ? "关闭测试字幕" : "显示测试字幕") {
                        coordinator.toggleStylePreview()
                    }
                    .disabled(coordinator.isRunning)
                }
            }
        }
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "lock.shield")
                .foregroundStyle(.secondary)
            Text("OCR 完全在本机进行。应用启动时会向 Google 发送一个固定标点预热连接，之后只发送识别到的字幕文字；无需密钥，但该非官方接口可能限流或变更。屏幕画面不会上传。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }

    private var statusColor: Color {
        switch coordinator.status {
        case .idle: .secondary
        case .selecting, .preparing, .waitingForAppleTV, .translating: .orange
        case .scanning: .green
        case .noText: .blue
        case .permissionRequired, .failed: .red
        }
    }
}

private struct Card<Content: View>: View {
    private let title: String?
    private let systemImage: String?
    private let content: Content

    init(
        title: String? = nil,
        systemImage: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            if let title {
                Label(title, systemImage: systemImage ?? "circle")
                    .font(.headline)
            }
            content
        }
        .padding(17)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}
