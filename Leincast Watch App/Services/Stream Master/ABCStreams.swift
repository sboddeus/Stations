
import Foundation

// Initial stations
let news = Stream(
    id: UUID().uuidString,
    title: "ABC News",
    description: "ABC News Broadcast",
    imageURL: URL(string: "https://upload.wikimedia.org/wikipedia/en/8/8c/ABC_HD_Australia_logo.png")!,
    url: URL(string: "https://mediaserviceslive.akamaized.net/hls/live/2038311/newsradio/masterhq.m3u8")!
)

let tripleJ = Stream(
    id: UUID().uuidString,
    title: "Triple J",
    description: "ABC Youth Station",
    imageURL: URL(string: "https://upload.wikimedia.org/wikipedia/en/8/8c/ABC_HD_Australia_logo.png")!,
    url: URL(string: "https://mediaserviceslive.akamaized.net/hls/live/2038308/triplejnsw/masterlq.m3u8")!
)

let SBS = Stream(
    id: UUID().uuidString,
    title: "SBS",
    description: "SBS Broadcast",
    imageURL: URL(string: "https://www.code4fun.com.au/wp-content/uploads/2014/09/SBS-logo.png")!,
    url: URL(string: "https://sbs-hls.streamguys1.com/hls/sbs1/playlist.m3u8")!
)

let tikTokTrending = Stream(
    id: UUID().uuidString,
    title: "TikTok",
    description: "TikTok Trending",
    imageURL: URL(string: "https://www.edigitalagency.com.au/wp-content/uploads/TikTok-icon-glyph.png")!,
    url: URL(string: "https://ais-arn.streamguys1.com/au_032/playlist.m3u8")!
)

let classic = Stream(
    id: UUID().uuidString,
    title: "ABC Classic",
    description: "Classical music broadcast",
    imageURL: URL(string: "https://upload.wikimedia.org/wikipedia/en/8/8c/ABC_HD_Australia_logo.png")!,
    url: URL(string: "https://mediaserviceslive.akamaized.net/hls/live/2038316/classicfmnsw/masterhq.m3u8")!
)

let kids = Stream(
    id: UUID().uuidString,
    title: "ABC Kids",
    description: "Kids music broadcast",
    imageURL: URL(string: "https://upload.wikimedia.org/wikipedia/en/8/8c/ABC_HD_Australia_logo.png")!,
    url: URL(string: "https://mediaserviceslive.akamaized.net/hls/live/2038321/abcextra/masterhq.m3u8")!
)

let bbcWorldwide = Stream(
    id: UUID().uuidString,
    title: "BBC Worldwide",
    description: "BCC Wordwide Service",
    imageURL: URL(string: "https://brandslogos.com/wp-content/uploads/images/large/bbc-logo-1.png")!,
    url: URL(string: "https://a.files.bbci.co.uk/media/live/manifesto/audio/simulcast/hls/nonuk/sbr_low/ak/bbc_world_service.m3u8")!
)

let bin = Stream(
    id: UUID().uuidString,
    title: "BIN",
    description: "Black information network",
    imageURL: nil,
    url: URL(string: "https://stream.revma.ihrhls.com/zc6066/hls.m3u8")!
)
