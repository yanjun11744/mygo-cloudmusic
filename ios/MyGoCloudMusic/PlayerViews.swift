import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject private var player: MusicPlayer
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        HStack(spacing: 12) {
            if let track = player.current {
                Button { player.showNowPlaying = true } label: {
                    HStack(spacing: 11) {
                        MusicCover(url: track.artworkURL, size: 48, corner: 8)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(track.title).font(.system(size: 13.5, weight: .semibold)).lineLimit(1)
                            Text(track.artist).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                        }
                        .frame(maxWidth: sizeClass == .compact ? .infinity : 220, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "music.note")
                    .frame(width: 48, height: 48)
                    .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                Text("未在播放")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if sizeClass != .compact { Spacer() }
            HStack(spacing: sizeClass == .compact ? 14 : 20) {
                if sizeClass != .compact {
                    Button { Task { await player.previous() } } label: {
                        Image(systemName: "backward.end.fill")
                    }
                }
                Button { player.toggle() } label: {
                    Image(systemName: player.playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 19))
                }
                .disabled(player.current == nil)
                Button { Task { await player.next() } } label: {
                    Image(systemName: "forward.end.fill")
                }
                .disabled(player.current == nil)
            }
            .buttonStyle(.plain)
            if sizeClass != .compact {
                Spacer()
                Text(musicTime(player.position))
                    .font(.system(size: 10.5).monospacedDigit())
                    .foregroundStyle(.secondary)
                Slider(value: Binding(get: { player.position },
                                      set: { player.seek(to: $0) }),
                       in: 0...max(1, player.duration))
                    .frame(width: 180)
                Text(musicTime(player.duration))
                    .font(.system(size: 10.5).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
    }
}

struct NowPlayingView: View {
    @EnvironmentObject private var player: MusicPlayer
    @Environment(\.dismiss) private var dismiss
    @State private var tab = 0

    private var track: MusicTrack? { player.current }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 11 / 255, green: 11 / 255, blue: 13 / 255).ignoresSafeArea()
                RadialGradient(colors: [Color.myGoAccent.opacity(0.28), .clear],
                               center: .topLeading, startRadius: 20, endRadius: 520)
                    .ignoresSafeArea()

                VStack(spacing: 22) {
                    HStack {
                        Button {
                            player.showNowPlaying = false
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 20, weight: .medium))
                        }
                        Spacer()
                        Picker("播放视图", selection: $tab) {
                            Text("歌词").tag(0)
                            Text("队列").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 160)
                        Spacer()
                        Image(systemName: "ellipsis")
                            .opacity(0)
                    }
                    .padding(.top, 8)

                    let coverSize = min(geometry.size.width - 72, geometry.size.height * 0.41, 390)
                    if let track {
                        MusicCover(url: track.artworkURL, size: coverSize, corner: 12)
                            .shadow(color: .black.opacity(0.35), radius: 26, y: 12)
                            .frame(maxWidth: .infinity)
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(track?.title ?? "未在播放")
                                .font(.system(size: 22, weight: .bold))
                                .lineLimit(1)
                            Text(track?.artist ?? "")
                                .font(.system(size: 15))
                                .foregroundStyle(.white.opacity(0.62))
                                .lineLimit(1)
                        }
                        Spacer()
                    }

                    if tab == 0 {
                        ScrollView {
                            Text(player.lyrics.isEmpty ? "暂无歌词" :
                                player.lyrics.split(separator: "\n").joined(separator: "\n"))
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.85))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 14) {
                                ForEach(player.queue) { item in
                                    HStack(spacing: 10) {
                                        MusicCover(url: item.artworkURL, size: 34, corner: 6)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.title).lineLimit(1)
                                            Text(item.artist).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: .infinity)
                    }

                    VStack(spacing: 12) {
                        Slider(value: Binding(get: { player.position },
                                              set: { player.seek(to: $0) }),
                               in: 0...max(1, player.duration))
                            .tint(.white)
                        HStack {
                            Text(musicTime(player.position))
                            Spacer()
                            Text("-" + musicTime(max(0, player.duration - player.position)))
                        }
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.52))
                    }
                    HStack(spacing: 44) {
                        Button { Task { await player.previous() } } label: {
                            Image(systemName: "backward.end.fill").font(.system(size: 25))
                        }
                        Button { player.toggle() } label: {
                            Image(systemName: player.playing ? "pause.fill" : "play.fill")
                                .font(.system(size: 34))
                                .frame(width: 60)
                        }
                        Button { Task { await player.next() } } label: {
                            Image(systemName: "forward.end.fill").font(.system(size: 25))
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 14)
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 12)
                .foregroundStyle(.white)
            }
        }
        .preferredColorScheme(.dark)
    }
}
