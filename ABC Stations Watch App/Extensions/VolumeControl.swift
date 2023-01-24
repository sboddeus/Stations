//
//  VolumeControl.swift
//  ABC Stations Watch App
//
//  Created by Sye Boddeus on 24/1/2023.
//

import Foundation
import SwiftUI

struct VolumeView: WKInterfaceObjectRepresentable {
    typealias WKInterfaceObjectType = WKInterfaceVolumeControl
    
    func makeWKInterfaceObject(context: Self.Context) -> WKInterfaceVolumeControl {
        let view = WKInterfaceVolumeControl(origin: .local)

        view.setTintColor(LeincastColors.brand.uiKitColor)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak view] in
            view?.focus()
        }
        return view
    }
    
    func updateWKInterfaceObject(_ wkInterfaceObject: WKInterfaceVolumeControl, context: WKInterfaceObjectRepresentableContext<VolumeView>) {
    }
}
