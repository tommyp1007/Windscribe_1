//
//  Constants.swift
//  Windscribe
//
//  Created by Yalcin on 2018-11-29.
//  Copyright © 2018 Windscribe. All rights reserved.
//

import Foundation

enum AppConstants {
    static let appName = "Windscribe"
    static let service = "WindscribeServerCreds"
    static let emergencyConfig = "emergency-connect"
}

/// Local debugging helpers. Set `forceProAccount` to `false` to restore normal free/pro behavior.
enum DebugConfiguration {
    static let forceProAccount = true
}
