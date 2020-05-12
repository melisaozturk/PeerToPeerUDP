//
//  Frame.swift
//  PearToPearNetwork
//
//  Created by melisa öztürk on 12.05.2020.
//  Copyright © 2020 melisa öztürk. All rights reserved.
//

import Foundation

class Frame {
    var frameID: UInt16!
    var segmentID: UInt16!
    var bufferData: Data!
    
    init(frameID: UInt16, segmentID: UInt16, bufferData: Data) {
        self.frameID = frameID
        self.segmentID = segmentID
        self.bufferData = bufferData
    }
}
