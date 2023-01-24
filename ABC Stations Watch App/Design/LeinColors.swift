//
//  LeinColors.swift
//  ABC Stations Watch App
//
//  Created by Sye Boddeus on 24/1/2023.
//

import SwiftUI

enum LeincastColors {
    case brand
    
    var color: Color {
        switch self {
        case .brand: return Color("BrandColor")
        }
    }
    
    var uiKitColor: UIColor {
        switch self {
        case .brand: return UIColor(named: "BrandColor")!
        }
    }
}
