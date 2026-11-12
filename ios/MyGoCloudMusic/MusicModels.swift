import Foundation

enum MusicPlatform: String, CaseIterable, Codable, Identifiable {
    case netease
    case qqmusic
    case fnmusic
    case songloft
    case subsonic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .netease: "网易云音乐"
        case .qqmusic: "QQ 音乐"
        case .fnmusic: "飞牛音乐"
        case .songloft: "Songloft"
        case .subsonic: "Subsonic"
        }
    }

    var symbol: String {
        switch self {
        case .netease: "music.note"
        case .qqmusic: "music.mic"
        case .fnmusic: "externaldrive"
        case .songloft: "music.note.house"
        case .subsonic: "server.rack"
        }
    }

    var available: Bool { self == .subsonic || self == .songloft }
}

struct ServerConfiguration: Codable {
    let address: String
    let username: String
    let password: String
}

struct MusicTrack: Identifiable, Hashable {
    let id: String
    let remoteID: String
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let artworkURL: URL?
    let source: MusicPlatform
    var favorite: Bool = false
}

struct MusicCollection: Identifiable, Hashable {
    enum Kind: String { case playlist, album, artist }
    let id: String
    let title: String
    let subtitle: String
    let artworkURL: URL?
    let kind: Kind
}

enum MusicPage: Hashable {
    case library
    case albums
    case artists
    case favorites
    case recent
    case folders
    case collection(MusicCollection)
    case search(String)

    var title: String {
        switch self {
        case .library: "音乐库"
        case .albums: "专辑"
        case .artists: "歌手"
        case .favorites: "我喜欢"
        case .recent: "最近播放"
        case .folders: "文件夹"
        case .collection(let collection): collection.title
        case .search: "搜索结果"
        }
    }

    var symbol: String {
        switch self {
        case .library: "music.note.list"
        case .albums: "square.stack"
        case .artists: "person.2"
        case .favorites: "heart"
        case .recent: "clock.arrow.circlepath"
        case .folders: "folder"
        case .collection: "music.note.list"
        case .search: "magnifyingglass"
        }
    }
}

enum MusicError: LocalizedError {
    case unsupported
    case invalidAddress
    case badResponse
    case missingStream
    case server(String)

    var errorDescription: String? {
        switch self {
        case .unsupported: "此平台的 iOS 接口尚未迁移。"
        case .invalidAddress: "服务器地址无效，请输入完整的 http:// 或 https:// 地址。"
        case .badResponse: "服务器返回的数据格式不正确。"
        case .missingStream: "无法获取这首歌曲的播放地址。"
        case .server(let message): message
        }
    }
}
