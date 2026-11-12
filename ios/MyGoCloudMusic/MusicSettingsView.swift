import SwiftUI

struct MusicSettingsView: View {
    @EnvironmentObject private var store: MusicStore
    @State private var address = ""
    @State private var username = ""
    @State private var password = ""
    @State private var showPassword = false

    var body: some View {
        Form {
            Section("音乐平台") {
                Picker("当前平台", selection: Binding(
                    get: { store.platform },
                    set: { platform in Task { await store.select(platform) } }
                )) {
                    ForEach(MusicPlatform.allCases) { platform in
                        Text(platform.title).tag(platform)
                    }
                }
            }

            if store.platform.available {
                Section("服务器") {
                    TextField("服务器地址", text: $address)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("用户名", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                    SecureField("密码", text: $password)
                        .textContentType(.password)

                    if store.connected {
                        Label("已连接", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    if let error = store.error {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                    Button(store.loading ? "正在连接…" : "连接") {
                        let config = ServerConfiguration(address: address,
                                                         username: username,
                                                         password: password)
                        Task { await store.connect(config) }
                    }
                    .disabled(store.loading || address.isEmpty || username.isEmpty || password.isEmpty)
                    if store.connected {
                        Button("断开并删除保存的凭据", role: .destructive) {
                            store.disconnect()
                        }
                    }
                }
            } else {
                Section {
                    Text("此平台仍保留在原 Go 桌面项目中，SwiftUI 版本尚未实现该平台的 API。")
                        .foregroundStyle(.secondary)
                }
            }

            Section("关于") {
                LabeledContent("应用", value: "MyGo CloudMusic iOS")
                LabeledContent("技术", value: "SwiftUI · AVFoundation")
                Text("iOS 原生移植预览版。暂不支持原版的 DLNA、DSD 解码、烟雾效果和刘海播放器。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("设置")
        .onAppear(perform: populate)
        .onChange(of: store.platform) { _, _ in populate() }
    }

    private func populate() {
        let config = SecretStore.load(for: store.platform)
        address = config?.address ?? ""
        username = config?.username ?? ""
        password = config?.password ?? ""
    }
}
