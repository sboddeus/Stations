//
//  RadioStation.swift
//  ABC Stations Watch App
//
//  Created by Sye Boddeus on 7/1/2023.
//

import Foundation

// MARK: - Radio Station

struct APITimeZone: Equatable {
    let code: String
    let name: String
    let offset: Double
}

struct RadioStation: Equatable, Identifiable {
    let id: String
    let title: String
    let description: String
    //let imageURL: URL?
    let url: URL
    //let timeZone: APITimeZone
}
