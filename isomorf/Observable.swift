//
//  Observable.swift
//  isomorf
//
//  Created by sumi on 2023/01/28.
//

import SwiftUI

class Observable: ObservableObject {
    @Published var timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    @Published var file: String? = nil
    
    @Published var align = Align.hex
    
    @Published var layout = Layout.janko {
        didSet {
            switch layout {
            case .janko:
                align = .hex
                gridX = 2
                gridY = 1
            case .wicki:
                align = .hex
                gridX = 2
                gridY = 7
            case .harmonic:
                align = .hex
                gridX = 4
                gridY = 7
            case .linn:
                align = .rect
                gridX = 1
                gridY = 5
            case .harpejji: 
                align = .rect
                gridX = 5
                gridY = 1
            case .dodeka:
                align = .rect
                gridX = 1
                gridY = 12
            }
        }
    }
    
    @Published var isTraditional = false
    
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
    
    @Published var coloursBlack = true
    
    @Published var root: Int = 0
    @Published var nRows: Int = 7
    @Published var nCols: Int = 12
    @Published var numberLowest: Int = 60
    @Published var instrument: Int = 0 {
        didSet {
            sampler.loadInstrument(instrument)
        }
    }
    
    @Published var gridX: Int = 2
    @Published var gridY: Int = 1
    
    func number(_ i: Int, _ j: Int) -> Number {
        switch align {
        case .rect:
            return numberLowest + j * gridX + i * gridY
        case .hex:
            return numberLowest + (j - i / 2) * gridX + i * gridY
        }
    }
    
    func roundNumber(_ i: Int, _ numberF: Float) -> Float {
        let from = Float(numberLowest + i * gridY)
        return round((numberF - from) / Float(gridX)) * Float(gridX) + from
    }
}
