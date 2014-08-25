//
//  ImageBuffer.swift
//  CesiumKit
//
//  Created by Ryan Walklin on 16/08/14.
//  Copyright (c) 2014 Test Toast. All rights reserved.
//

/// RGBA image data
class ImageBuffer {
    let width: Int
    let height: Int
    let arrayBufferView: [UInt8]
    
    init(width: Int, height: Int, arrayBufferView: [UInt8]) {
        self.width = width
        self.height = height
        self.arrayBufferView = arrayBufferView
    }
    
}