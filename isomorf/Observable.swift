//
//  Observable.swift
//  isomorf
//
//  Created by sumi on 2023/01/28.
//

import SwiftUI

class Observable: ObservableObject {
    @Published var timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    @Published var layout = Layout.janko
    
    
    @Published var sampler = Sampler()
    
    @Published var sustains: Bool = false {
        didSet {
            if(!sustains) {
                sampler.unsustain()
            }
        }
    }
    @Published var sustainsAlways: Bool = false {
        didSet { changeSustains() }
    }
    @Published var sustainsCurrently: Bool = false {
        didSet { changeSustains() }
    }
    func changeSustains() {
        sustains = sustainsAlways || sustainsCurrently
    }
    
    @Published var bends: Bool = false {
        didSet {
            if(!bends) {
                sampler.unbend()
            }
        }
    }
    @Published var bendsAlways: Bool = false {
        didSet { changeBends() }
    }
    @Published var bendsCurrently: Bool = false {
        didSet { changeBends() }
    }
    func changeBends() {
        bends = bendsAlways || bendsCurrently
    }
    
    @Published var root: Int = 0
    @Published var nRows: Int = 4
    @Published var nCols: Int = 12
    @Published var numberLowest: Int = 57
    @Published var instrument: UInt8 = 0 {
        didSet {
            sampler.loadInstrument(instrument)
        }
    }
    
    @Published var gridX: Int = 1
    @Published var gridY: Int = 5
    
    var diffPerKey: Float {
        switch layout {
        case .janko:
            return 2
        case .grid:
            return Float(gridX)
        }
    }
    
    func gridNumber(_ i: Int, _ j: Int) -> Number {
        return numberLowest + i * gridY + j * gridX
    }
    
    func reset() {
        nRows = 4
        nCols = 12
        numberLowest = 57
    }
    
    @Published var config = Config.janko {
        didSet {
            reset()

            switch config {
            case .janko:
                layout = .janko
            case .linn4:
                layout = .grid
                gridX = 1
                gridY = 4
                numberLowest -= 12
            case .linn:
                layout = .grid
                gridX = 1
                gridY = 5
                numberLowest -= 12
            case .linn6:
                layout = .grid
                gridX = 1
                gridY = 6
                numberLowest -= 12
            case .dodeka:
                layout = .grid
                gridX = 1
                nRows = 1
            case .harpejji:
                layout = .grid
                gridX = 5
                gridY = 1
                nRows = 12
                nCols = 8
            }
        }
    }
}