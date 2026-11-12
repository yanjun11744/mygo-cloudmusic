import SwiftUI

struct MusicRootView: View {
    @EnvironmentObject private var store: MusicStore
    @EnvironmentObject private var player: MusicPlayer
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.colorScheme) private var scheme
    @State private var showNavigation = false
    @State private var connectionOpen = false

    private var compact: Bool { sizeClass == .compact }

    var body: some View {
        HStack(spacing: 0) {
            if !compact {
                MusicSidebar(onDismiss: {})
                    .frame(width: 232)
                Rectangle().fill(MusicTheme.line(scheme)).frame(width: 1)
            }

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    if compact {
                        Button { showNavigation = true } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 18, weight: .medium))
                        }
                        .accessibilityLabel("打开导航")
                    }
                    Text(store.page.title)
                        .font(.system(size: compact ? 18 : 20, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    Button {
                        store.showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("设置")
                }
                .padding(.horizontal, 20)
                .frame(height: 48)

                MusicContentView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Rectangle().fill(MusicTheme.line(scheme)).frame(height: 1)
                MiniPlayerView()
                    .frame(height: compact ? 74 : 84)
            }
            .background(MusicTheme.background(scheme))
        }
        .foregroundStyle(MusicTheme.primary(scheme))
        .background(MusicTheme.sidebar(scheme))
        .sheet(isPresented: $showNavigation) {
            NavigationStack {
                MusicSidebar { showNavigation = false }
                    .navigationTitle("音乐")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("完成") { showNavigation = false }
                        }
                    }
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $store.showSettings) {
            NavigationStack {
                MusicSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("完成") { store.showSettings = false }
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $player.showNowPlaying) {
            NowPlayingView()
        }
    }
}

struct MusicSidebar: View {
    @EnvironmentObject private var store: MusicStore
    @EnvironmentObject private var player: MusicPlayer
    @Environment(\.colorScheme) private var scheme
    var onDismiss: () -> Void

    private let pages: [MusicPage] = [.library, .albums, .artists, .favorites, .recent, .folders]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索歌曲、专辑、歌手", text: $store.search)
                    .font(.system(size: 13))
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await store.submitSearch() }
                        onDismiss()
                    }
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(MusicTheme.rowHover(scheme), in: RoundedRectangle(cornerRadius: 9))
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(pages, id: \.self) { page in
                        Button {
                            Task { await store.navigate(page) }
                            onDismiss()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: page.symbol)
                                    .frame(width: 18)
                                    .foregroundStyle(store.page == page ? Color.myGoAccent : MusicTheme.secondary(scheme))
                                Text(page.title)
                                    .font(.system(size: 13.5, weight: .medium))
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 34)
                            .background(store.page == page ? MusicTheme.selected(scheme) : .clear,
                                        in: RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer(minLength: 0)
            if let track = player.current {
                Button {
                    player.showNowPlaying = true
                    onDismiss()
                } label: {
                    HStack(spacing: 10) {
                        MusicCover(url: track.artworkURL, size: 40, corner: 6)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title).font(.system(size: 12.5, weight: .semibold)).lineLimit(1)
                            Text(track.artist).font(.system(size: 11.5)).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(8)
                    .background(MusicTheme.rowHover(scheme), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            Button {
                store.showSettings = true
                onDismiss()
            } label: {
                Label("设置", systemImage: "gearshape")
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .buttonStyle(.plain)

            Menu {
                ForEach(MusicPlatform.allCases) { platform in
                    Button {
                        Task { await store.select(platform) }
                        onDismiss()
                    } label: {
                        Label(platform.title, systemImage: platform.symbol)
                    }
                }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: store.platform.symbol)
                        .font(.system(size: 15))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.platform.title).font(.system(size: 12.5, weight: .semibold))
                        Text(store.connected ? "已连接" : "未连接")
                            .font(.system(size: 11.5)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .frame(height: 48)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .frame(maxHeight: .infinity)
        .background(MusicTheme.sidebar(scheme))
    }
}

struct MusicContentView: View {
    @EnvironmentObject private var store: MusicStore
    @EnvironmentObject private var player: MusicPlayer
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if !store.connected {
                ContentUnavailableView {
                    Label(store.platform.title, systemImage: store.platform.symbol)
                } description: {
                    Text(store.platform.available
                         ? "连接音乐服务器，开始浏览你的音乐库。"
                         : "此音乐源的 iOS 接口尚未迁移，暂不支持连接。")
                } actions: {
                    if store.platform.available {
                        Button("连接服务器") { store.showSettings = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if case .collection(let collection) = store.page {
                            HStack(spacing: 18) {
                                MusicCover(url: collection.artworkURL, size: 116, corner: 12)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(collection.title)
                                        .font(.system(size: 27, weight: .bold))
                                        .lineLimit(2)
                                    Text(collection.subtitle)
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                    Button {
                                        playFirst()
                                    } label: {
                                        Label("播放", systemImage: "play.fill")
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                            .padding(.top, 16)
                        } else {
                            Text(store.page.title)
                                .font(.system(size: 28, weight: .bold))
                                .padding(.top, 18)
                        }

                        if store.loading {
                            ProgressView("正在加载…").frame(maxWidth: .infinity).padding(30)
                        } else if let error = store.error {
                            ContentUnavailableView(error, systemImage: "exclamationmark.triangle")
                        } else if !store.collections.isEmpty {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 220), spacing: 18)], spacing: 22) {
                                ForEach(store.collections) { collection in
                                    Button {
                                        Task { await store.navigate(.collection(collection)) }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 7) {
                                            GeometryReader { geometry in
                                                MusicCover(url: collection.artworkURL, size: geometry.size.width, corner: 12)
                                            }
                                            .aspectRatio(1, contentMode: .fit)
                                            Text(collection.title).font(.system(size: 13.5, weight: .semibold)).lineLimit(1)
                                            Text(collection.subtitle).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } else if !store.tracks.isEmpty {
                            LazyVStack(spacing: 1) {
                                ForEach(Array(store.tracks.enumerated()), id: \.element.id) { i, track in
                                    MusicTrackRow(track: track, number: i + 1)
                                }
                            }
                        } else {
                            ContentUnavailableView("暂无内容", systemImage: "music.note")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func playFirst() {
        guard let first = store.tracks.first, let service = store.service else { return }
        store.record(first)
        Task { await player.play(first, from: store.tracks, using: service) }
    }
}

struct MusicCover: View {
    let url: URL?
    var size: CGFloat
    var corner: CGFloat = 8

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Rectangle().fill(.primary.opacity(0.06))
                .overlay {
                    Image(systemName: "music.note")
                        .foregroundStyle(.tertiary)
                        .font(.system(size: min(size / 3, 28)))
                }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: corner))
    }
}

struct MusicTrackRow: View {
    @EnvironmentObject private var store: MusicStore
    @EnvironmentObject private var player: MusicPlayer
    let track: MusicTrack
    let number: Int

    var body: some View {
        HStack(spacing: 12) {
            Text(String(number))
                .font(.system(size: 12.5, design: .rounded))
                .foregroundStyle(.tertiary)
                .frame(width: 24)
            MusicCover(url: track.artworkURL, size: 46, corner: 7)
            Button {
                guard let service = store.service else { return }
                store.record(track)
                Task { await player.play(track, from: store.tracks, using: service) }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.system(size: 13.5, weight: .medium))
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            Button {
                Task { await store.toggleLike(track) }
            } label: {
                Image(systemName: track.favorite ? "heart.fill" : "heart")
                    .foregroundStyle(track.favorite ? Color.myGoAccent : .secondary)
                    .font(.system(size: 15))
            }
            .buttonStyle(.plain)
            Text(musicTime(track.duration))
                .font(.system(size: 12.5).monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(minWidth: 35, alignment: .trailing)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }
}
