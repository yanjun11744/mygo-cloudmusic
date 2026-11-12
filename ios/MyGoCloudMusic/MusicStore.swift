import Foundation
import SwiftUI
import Security

enum SecretStore {
    static func save(_ config: ServerConfiguration, for platform: MusicPlatform) throws {
        let bytes = try JSONEncoder().encode(config)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "MyGoCloudMusic.iOS",
            kSecAttrAccount as String: platform.rawValue
        ]
        SecItemDelete(query as CFDictionary)
        var create = query
        create[kSecValueData as String] = bytes
        create[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let result = SecItemAdd(create as CFDictionary, nil)
        guard result == errSecSuccess else { throw MusicError.server("无法保存登录信息") }
    }

    static func load(for platform: MusicPlatform) -> ServerConfiguration? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "MyGoCloudMusic.iOS",
            kSecAttrAccount as String: platform.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let bytes = result as? Data else { return nil }
        return try? JSONDecoder().decode(ServerConfiguration.self, from: bytes)
    }

    static func remove(for platform: MusicPlatform) {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "MyGoCloudMusic.iOS",
            kSecAttrAccount as String: platform.rawValue
        ] as CFDictionary)
    }
}

@MainActor
final class MusicStore: ObservableObject {
    @Published var platform: MusicPlatform = .subsonic
    @Published var connected = false
    @Published var loading = false
    @Published var error: String?
    @Published var tracks: [MusicTrack] = []
    @Published var collections: [MusicCollection] = []
    @Published var page: MusicPage = .library
    @Published var search = ""
    @Published var recent: [MusicTrack] = []
    @Published var showSettings = false

    private(set) var service: (any MusicService)?

    init() {
        if let saved = UserDefaults.standard.string(forKey: "music.platform"),
           let kind = MusicPlatform(rawValue: saved) {
            platform = kind
        }
    }

    func restore() async {
        guard platform.available, let config = SecretStore.load(for: platform) else { return }
        await connect(config, save: false)
    }

    func select(_ platform: MusicPlatform) async {
        self.platform = platform
        UserDefaults.standard.set(platform.rawValue, forKey: "music.platform")
        service = nil
        connected = false
        tracks = []
        collections = []
        page = .library
        error = nil
        await restore()
    }

    func connect(_ config: ServerConfiguration, save: Bool = true) async {
        guard platform.available else {
            error = MusicError.unsupported.localizedDescription
            return
        }
        loading = true
        error = nil
        do {
            let provider: any MusicService
            switch platform {
            case .subsonic: provider = try SubsonicService(config: config)
            case .songloft: provider = try SongloftService(config: config)
            default: throw MusicError.unsupported
            }
            try await provider.connect()
            service = provider
            connected = true
            if save { try SecretStore.save(config, for: platform) }
            await navigate(.library)
        } catch {
            connected = false
            self.error = error.localizedDescription
        }
        loading = false
    }

    func disconnect() {
        SecretStore.remove(for: platform)
        service = nil
        connected = false
        tracks = []
        collections = []
    }

    func navigate(_ page: MusicPage) async {
        self.page = page
        guard let service, connected else { return }
        loading = true
        error = nil
        do {
            switch page {
            case .library:
                tracks = try await service.songs(query: nil)
                collections = []
            case .albums:
                collections = try await service.collections(kind: .album)
                tracks = []
            case .artists:
                collections = try await service.collections(kind: .artist)
                tracks = []
            case .favorites:
                tracks = tracks.filter(\.favorite)
                collections = []
            case .recent:
                tracks = recent
                collections = []
            case .folders:
                tracks = []
                collections = []
                error = "文件夹浏览将在后续迁移版本中支持。"
            case .collection(let collection):
                tracks = try await service.tracks(in: collection)
                collections = []
            case .search(let query):
                tracks = try await service.songs(query: query)
                collections = []
            }
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    func submitSearch() async {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty { await navigate(.search(query)) }
    }

    func record(_ track: MusicTrack) {
        recent.removeAll { $0.id == track.id }
        recent.insert(track, at: 0)
        if recent.count > 100 { recent.removeLast() }
    }

    func toggleLike(_ track: MusicTrack) async {
        guard let service else { return }
        do {
            let next = !track.favorite
            try await service.setFavorite(next, for: track)
            if let i = tracks.firstIndex(where: { $0.id == track.id }) {
                tracks[i].favorite = next
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
