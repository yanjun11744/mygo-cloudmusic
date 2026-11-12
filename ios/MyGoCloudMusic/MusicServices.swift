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

