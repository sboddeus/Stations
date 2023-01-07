//
//  ABCStations.swift
//  ABC Stations Watch App
//
//  Created by Sye Boddeus on 7/1/2023.
//

import Foundation

let news = RadioStation(
    id: "ABC NEWS GLOBAL",
    title: "ABC News",
    description: "ABC News Broadcast",
    url: URL(string: "https://mediaserviceslive.akamaized.net/hls/live/2038311/newsradio/masterhq.m3u8")!
)

let tripleJ = RadioStation(
    id: "ABC TRIPLE J",
    title: "Triple J",
    description: "ABC Youth Station",
    url: URL(string: "https://mediaserviceslive.akamaized.net/hls/live/2038308/triplejnsw/masterlq.m3u8")!
)

let classic = RadioStation(
    id: "ABC CLASSIC",
    title: "ABC Classic",
    description: "Classical music broadcast",
    url: URL(string: "https://mediaserviceslive.akamaized.net/hls/live/2038316/classicfmnsw/masterhq.m3u8")!
)

let kids = RadioStation(
    id: "ABC KIDS",
    title: "ABC Kids",
    description: "Kids music broadcast",
    url: URL(string: "https://mediaserviceslive.akamaized.net/hls/live/2038321/abcextra/masterhq.m3u8")!
)
