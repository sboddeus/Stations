//
//  ABCStations.swift
//  ABC Stations Watch App
//
//  Created by Sye Boddeus on 7/1/2023.
//

import Foundation

// Initial stations
let news = Station(
    id: UUID(),
    title: "ABC News",
    description: "ABC News Broadcast",
    imageURL: URL(string: "https://upload.wikimedia.org/wikipedia/en/8/8c/ABC_HD_Australia_logo.png")!,
    url: URL(string: "https://mediaserviceslive.akamaized.net/hls/live/2038311/newsradio/masterhq.m3u8")!
)

let tripleJ = Station(
    id: UUID(),
    title: "Triple J",
    description: "ABC Youth Station",
    imageURL: URL(string: "https://upload.wikimedia.org/wikipedia/en/8/8c/ABC_HD_Australia_logo.png")!,
    url: URL(string: "https://mediaserviceslive.akamaized.net/hls/live/2038308/triplejnsw/masterlq.m3u8")!
)

let SBS = Station(
    id: UUID(),
    title: "SBS",
    description: "SBS Broadcast",
    imageURL: URL(string: "https://www.code4fun.com.au/wp-content/uploads/2014/09/SBS-logo.png")!,
    url: URL(string: "https://sbs-hls.streamguys1.com/hls/sbs1/playlist.m3u8")!
)

let tikTokTrending = Station(
    id: UUID(),
    title: "TikTok",
    description: "TikTok Trending",
    imageURL: URL(string: "https://www.edigitalagency.com.au/wp-content/uploads/TikTok-icon-glyph.png")!,
    url: URL(string: "https://ais-arn.streamguys1.com/au_032/playlist.m3u8")!
)

let classic = Station(
    id: UUID(),
    title: "ABC Classic",
    description: "Classical music broadcast",
    imageURL: URL(string: "https://upload.wikimedia.org/wikipedia/en/8/8c/ABC_HD_Australia_logo.png")!,
    url: URL(string: "https://mediaserviceslive.akamaized.net/hls/live/2038316/classicfmnsw/masterhq.m3u8")!
)

let kids = Station(
    id: UUID(),
    title: "ABC Kids",
    description: "Kids music broadcast",
    imageURL: URL(string: "https://upload.wikimedia.org/wikipedia/en/8/8c/ABC_HD_Australia_logo.png")!,
    url: URL(string: "https://mediaserviceslive.akamaized.net/hls/live/2038321/abcextra/masterhq.m3u8")!
)

let bbcWorldwide = Station(
    id: UUID(),
    title: "BBC Worldwide",
    description: "BCC Wordwide Service",
    imageURL: URL(string: "https://brandslogos.com/wp-content/uploads/images/large/bbc-logo-1.png")!,
    url: URL(string: "https://a.files.bbci.co.uk/media/live/manifesto/audio/simulcast/hls/nonuk/sbr_low/ak/bbc_world_service.m3u8")!
)

let bin = Station(
    id: UUID(),
    title: "BIN",
    description: "Black information network",
    imageURL: nil,
    url: URL(string: "https://stream.revma.ihrhls.com/zc6066/hls.m3u8")!
)
