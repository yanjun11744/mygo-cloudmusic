import AVFoundation
import Foundation
import MediaPlayer
import UIKit

@MainActor
final class MusicPlayer: ObservableObject {
    @Published private(set) var current: MusicTrack?
    @Published private(set) var playing = false
    @Published private(set) var position: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var queue: [MusicTrack] = []
    @Published var showNowPlaying = false
    @Published var lyrics = ""
    @Published var playbackError: String?

    private var player: AVPlayer?
    private var token: Any?
    private var endObserver: NSObjectProtocol?
    private var service: (any MusicService)?
    private var index = 0

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        UIApplication.shared.beginReceivingRemoteControlEvents()
        configureRemote()
    }

    func play(_ track: MusicTrack, from tracks: [MusicTrack], using service: any MusicService) async {
        self.service = service
        queue = tracks
        index = max(0, queue.firstIndex(where: { $0.id == track.id }) ?? 0)
        await start(track)
    }

    private func start(_ track: MusicTrack) async {
        playbackError = nil
        do {
            let url = try service?.streamURL(for: track)
            guard let url else { throw MusicError.missingStream }
            detach()
            current = track
            position = 0
            duration = track.duration
            let player = AVPlayer(url: url)
            self.player = player
            token = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
                                                   queue: .main) { [weak self] time in
                Task { @MainActor [weak self] in
                    self?.position = max(0, time.seconds.isFinite ? time.seconds : 0)
                    self?.updateNowPlaying()
                }
            }
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in await self?.next() }
            }
            try AVAudioSession.sharedInstance().setActive(true)
            player.play()
            playing = true
            updateNowPlaying()
            lyrics = (try? await service?.lyrics(for: track)) ?? ""
        } catch {
            playing = false
            playbackError = error.localizedDescription
        }
    }

    func toggle() {
        guard let player else { return }
        if playing { player.pause() } else { player.play() }
        playing.toggle()
        updateNowPlaying()
    }

    func seek(to seconds: TimeInterval) {
        let time = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
        player?.seek(to: time)
        position = seconds
    }

    func next() async {
        guard !queue.isEmpty else { return }
        index = (index + 1) % queue.count
        await start(queue[index])
    }

    func previous() async {
        guard !queue.isEmpty else { return }
        if position > 3 { seek(to: 0); return }
        index = (index - 1 + queue.count) % queue.count
        await start(queue[index])
    }

    private func detach() {
        if let token, let player { player.removeTimeObserver(token) }
        token = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        player?.pause()
    }

    private func configureRemote() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                if self?.playing == false { self?.toggle() }
            }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                if self?.playing == true { self?.toggle() }
            }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in await self?.next() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in await self?.previous() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let change = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor [weak self] in self?.seek(to: change.positionTime) }
            return .success
        }
    }

    private func updateNowPlaying() {
        guard let track = current else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.album,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
            MPNowPlayingInfoPropertyPlaybackRate: playing ? 1 : 0
        ]
    }
}

func musicTime(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite else { return "0:00" }
    let value = max(0, Int(seconds))
    return String(format: "%d:%02d", value / 60, value % 60)
}
