import Foundation
import CryptoKit

protocol MusicService {
    func connect() async throws
    func songs(query: String?) async throws -> [MusicTrack]
    func collections(kind: MusicCollection.Kind) async throws -> [MusicCollection]
    func tracks(in collection: MusicCollection) async throws -> [MusicTrack]
    func streamURL(for track: MusicTrack) throws -> URL
    func lyrics(for track: MusicTrack) async throws -> String
    func setFavorite(_ favorite: Bool, for track: MusicTrack) async throws
    func artwork(for track: MusicTrack) async throws -> Data?
}

extension MusicService {
    func artwork(for track: MusicTrack) async throws -> Data? {
        guard let url = track.artworkURL else { return nil }
        return try await URLSession.shared.data(from: url).0
    }
}

private struct SubsonicEnvelope<T: Decodable>: Decodable {
    let response: T
    enum CodingKeys: String, CodingKey { case response = "subsonic-response" }
}
private struct SubsonicPayload: Decodable {
    let status: String
    let error: SubsonicError?
    let directory: SubsonicDirectory?
    let albumList2: SubsonicAlbumList?
    let artists: SubsonicArtists?
    let searchResult3: SubsonicSearch?
    let playlists: SubsonicPlaylists?
    let playlist: SubsonicPlaylist?\n    let album: SubsonicAlbumDetail?
    let lyrics: SubsonicLyrics?
}
private struct SubsonicError: Decodable { let message: String? }
private struct SubsonicDirectory: Decodable { let child: [SubsonicSong]? }
private struct SubsonicAlbumList: Decodable { let album: [SubsonicAlbum]? }\nprivate struct SubsonicAlbumDetail: Decodable { let song: [SubsonicSong]? }
private struct SubsonicArtists: Decodable { let index: [SubsonicArtistIndex]? }
private struct SubsonicArtistIndex: Decodable { let artist: [SubsonicArtist]? }
private struct SubsonicArtist: Decodable {
    let id: String
    let name: String
    let coverArt: String?
}
private struct SubsonicAlbum: Decodable {
    let id: String
    let name: String
    let artist: String?
    let coverArt: String?
}
private struct SubsonicSearch: Decodable {
    let song: [SubsonicSong]?
    let album: [SubsonicAlbum]?
    let artist: [SubsonicArtist]?
}
private struct SubsonicPlaylists: Decodable { let playlist: [SubsonicPlaylist]? }
private struct SubsonicPlaylist: Decodable {
    let id: String
    let name: String
    let songCount: Int?
    let coverArt: String?
    let entry: [SubsonicSong]?
}
private struct SubsonicLyrics: Decodable { let value: String? }
private struct SubsonicSong: Decodable {
    let id: String
    let title: String
    let artist: String?
    let album: String?
    let duration: Double?
    let coverArt: String?
    let starred: String?
}

final class SubsonicService: MusicService {
    private let config: ServerConfiguration
    private let baseURL: URL
    private let auth: [URLQueryItem]

    init(config: ServerConfiguration) throws {
        guard let url = URL(string: config.address),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host != nil else { throw MusicError.invalidAddress }
        self.config = config
        self.baseURL = url
        let salt = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12)
        let hash = Insecure.MD5.hash(data: Data((config.password + salt).utf8))
            .map { String(format: "%02x", $0) }.joined()
        self.auth = [
            URLQueryItem(name: "u", value: config.username),
            URLQueryItem(name: "t", value: hash),
            URLQueryItem(name: "s", value: String(salt)),
            URLQueryItem(name: "v", value: "1.16.1"),
            URLQueryItem(name: "c", value: "MyGoCloudMusic-iOS"),
            URLQueryItem(name: "f", value: "json")
        ]
    }

    private func endpoint(_ method: String, _ items: [URLQueryItem] = []) throws -> URL {
        var url = baseURL
        for component in ["rest", method + ".view"] {
            url.appendPathComponent(component)
        }
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw MusicError.invalidAddress
        }
        parts.queryItems = auth + items
        guard let result = parts.url else { throw MusicError.invalidAddress }
        return result
    }

    private func request(_ method: String, _ items: [URLQueryItem] = []) async throws -> SubsonicPayload {
        let url = try endpoint(method, items)
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw MusicError.badResponse
        }
        let value = try JSONDecoder().decode(SubsonicEnvelope<SubsonicPayload>.self, from: data).response
        guard value.status == "ok" else {
            throw MusicError.server(value.error?.message ?? "Subsonic 服务返回错误")
        }
        return value
    }

    private func cover(_ id: String?) -> URL? {
        guard let id, !id.isEmpty else { return nil }
        return try? endpoint("getCoverArt", [
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "size", value: "600")
        ])
    }

    private func track(_ item: SubsonicSong) -> MusicTrack {
        MusicTrack(id: "subsonic:" + item.id, remoteID: item.id,
                   title: item.title, artist: item.artist ?? "未知歌手",
                   album: item.album ?? "", duration: item.duration ?? 0,
                   artworkURL: cover(item.coverArt), source: .subsonic,
                   favorite: item.starred != nil)
    }

    func connect() async throws {
        _ = try await request("ping")
    }

    func songs(query: String?) async throws -> [MusicTrack] {
        if let query, !query.isEmpty {
            return try await request("search3", [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "songCount", value: "100"),
                URLQueryItem(name: "albumCount", value: "0"),
                URLQueryItem(name: "artistCount", value: "0")
            ]).searchResult3?.song?.map(track) ?? []
        }
        let albums = try await collections(kind: .album)
        var result: [MusicTrack] = []
        for album in albums.prefix(20) {
            result += try await detailTracks("getAlbum", id: album.id, key: "album")
        }
        return result
    }


    func collections(kind: MusicCollection.Kind) async throws -> [MusicCollection] {
        switch kind {
        case .playlist:
            let data = try await request("getPlaylists")
            return (data.playlists?.playlist ?? []).map {
                MusicCollection(id: $0.id, title: $0.name, subtitle: "\($0.songCount ?? 0) 首歌曲",
                                artworkURL: cover($0.coverArt), kind: .playlist)
            }
        case .album:
            let data = try await request("getAlbumList2", [
                URLQueryItem(name: "type", value: "newest"),
                URLQueryItem(name: "size", value: "100")
            ])
            return (data.albumList2?.album ?? []).map {
                MusicCollection(id: $0.id, title: $0.name, subtitle: $0.artist ?? "",
                                artworkURL: cover($0.coverArt), kind: .album)
            }
        case .artist:
            let data = try await request("getArtists")
            return (data.artists?.index ?? []).flatMap { $0.artist ?? [] }.map {
                MusicCollection(id: $0.id, title: $0.name, subtitle: "歌手",
                                artworkURL: cover($0.coverArt), kind: .artist)
            }
        }
    }

    func tracks(in collection: MusicCollection) async throws -> [MusicTrack] {
        switch collection.kind {
        case .playlist:
            return try await request("getPlaylist", [URLQueryItem(name: "id", value: collection.id)])
                .playlist?.entry?.map(track) ?? []
        case .album:
            return try await detailTracks("getAlbum", id: collection.id, key: "album")
        case .artist:
            let data = try await request("getArtist", [URLQueryItem(name: "id", value: collection.id)])
            _ = data
            return []
        }
    }

    private func detailTracks(_ method: String, id: String, key: String) async throws -> [MusicTrack] {
        let (data, _) = try await URLSession.shared.data(from: endpoint(method, [
            URLQueryItem(name: "id", value: id)
        ]))
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let container = (root?["subsonic-response"] as? [String: Any])?[key] as? [String: Any]
        let entries = container?["song"] as? [[String: Any]] ?? []
        let decoder = JSONDecoder()
        return try entries.map {
            let json = try JSONSerialization.data(withJSONObject: $0)
            return track(try decoder.decode(SubsonicSong.self, from: json))
        }
    }

    func streamURL(for track: MusicTrack) throws -> URL {
        try endpoint("stream", [URLQueryItem(name: "id", value: track.remoteID)])
    }

    func lyrics(for track: MusicTrack) async throws -> String {
        try await request("getLyrics", [URLQueryItem(name: "id", value: track.remoteID)])
            .lyrics?.value ?? ""
    }

    func setFavorite(_ favorite: Bool, for track: MusicTrack) async throws {
        _ = try await request(favorite ? "star" : "unstar", [
            URLQueryItem(name: "id", value: track.remoteID)
        ])
    }
}

private struct SongloftSongs: Decodable { let songs: [SongloftSong] }
private struct SongloftSong: Decodable {
    let id: Int64
    let title: String
    let artist: String
    let album: String
    let duration: Double
}
private struct SongloftLogin: Decodable {
    let accessToken: String
    enum CodingKeys: String, CodingKey { case accessToken = "access_token" }
}
private struct SongloftLyrics: Decodable { let lyric: String }
private struct SongloftPlaylistResponse: Decodable { let playlists: [SongloftPlaylist] }
private struct SongloftPlaylist: Decodable {
    let id: Int64
    let name: String
    let songCount: Int
    enum CodingKeys: String, CodingKey { case id, name; case songCount = "song_count" }
}
private struct SongloftFacetResponse: Decodable { let facets: [SongloftFacet] }
private struct SongloftFacet: Decodable { let value: String; let count: Int }

final class SongloftService: MusicService {
    private let config: ServerConfiguration
    private let baseURL: URL
    private var token = ""

    init(config: ServerConfiguration) throws {
        guard let url = URL(string: config.address),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host != nil else { throw MusicError.invalidAddress }
        self.config = config
        self.baseURL = url
    }

    private func url(_ path: String, query: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw MusicError.invalidAddress
        }
        components.path = baseURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .isEmpty ? path : "/" + baseURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + path
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw MusicError.invalidAddress }
        return url
    }

    private func request<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        var request = URLRequest(url: try url(path, query: query))
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MusicError.server("Songloft 请求失败")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func connect() async throws {
        var request = URLRequest(url: try url("/api/v1/auth/login"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "username": config.username, "password": config.password
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw MusicError.server("Songloft 登录失败，请检查账号和地址")
        }
        token = try JSONDecoder().decode(SongloftLogin.self, from: data).accessToken
    }

    private func convert(_ s: SongloftSong) -> MusicTrack {
        MusicTrack(id: "songloft:\(s.id)", remoteID: String(s.id),
                   title: s.title, artist: s.artist, album: s.album,
                   duration: s.duration, artworkURL: try? url("/api/v1/songs/\(s.id)/cover"),
                   source: .songloft)
    }

    func songs(query: String?) async throws -> [MusicTrack] {
        var items = [URLQueryItem(name: "limit", value: "100")]
        if let query, !query.isEmpty {
            items.append(URLQueryItem(name: "keyword", value: query))
        }
        let data: SongloftSongs = try await request("/api/v1/songs", query: items)
        return data.songs.map(convert)
    }

    func collections(kind: MusicCollection.Kind) async throws -> [MusicCollection] {
        switch kind {
        case .playlist:
            let result: SongloftPlaylistResponse = try await request("/api/v1/playlists")
            return result.playlists.map {
                MusicCollection(id: String($0.id), title: $0.name,
                                subtitle: "\($0.songCount) 首歌曲", artworkURL: nil, kind: .playlist)
            }
        case .album, .artist:
            let field = kind == .album ? "album" : "artist"
            let result: SongloftFacetResponse = try await request("/api/v1/songs/facets", query: [
                URLQueryItem(name: "field", value: field),
                URLQueryItem(name: "limit", value: "100")
            ])
            return result.facets.map {
                MusicCollection(id: $0.value, title: $0.value,
                                subtitle: "\($0.count) 首歌曲", artworkURL: nil, kind: kind)
            }
        }
    }

    func tracks(in collection: MusicCollection) async throws -> [MusicTrack] {
        if collection.kind == .playlist {
            let result: SongloftSongs = try await request("/api/v1/playlists/\(collection.id)/songs")
            return result.songs.map(convert)
        }
        let field = collection.kind == .album ? "album" : "artist"
        let result: SongloftSongs = try await request("/api/v1/songs", query: [
            URLQueryItem(name: field, value: collection.id),
            URLQueryItem(name: "limit", value: "100")
        ])
        return result.songs.map(convert)
    }

    func streamURL(for track: MusicTrack) throws -> URL {
        try url("/api/v1/songs/\(track.remoteID)/play",
                query: [URLQueryItem(name: "access_token", value: token)])
    }

    func lyrics(for track: MusicTrack) async throws -> String {
        let result: SongloftLyrics = try await request("/api/v1/songs/\(track.remoteID)/lyric")
        return result.lyric
    }

    func setFavorite(_ favorite: Bool, for track: MusicTrack) async throws {
        throw MusicError.unsupported
    }

    func artwork(for track: MusicTrack) async throws -> Data? {
        guard let url = track.artworkURL else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        return try await URLSession.shared.data(for: request).0
    }
}
