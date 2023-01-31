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
    
    @Published var root: Int = 0
    @Published var nRows: Int = 4
    @Published var nCols: Int = 12
    @Published var numberLowest: Int = 57
    @Published var instrument: Int = 0 {
        didSet {
            sampler.loadInstrument(instrument)
        }
    }
    
    @Published var gridX: Int = 2
    @Published var gridY: Int = 1
    
    func reset() {
        nRows = 4
        nCols = 12
        numberLowest = 57
    }
   
    func number(_ i: Int, _ j: Int) -> Number {
        return numberLowest + j * gridX + (i % 2) * gridY
    }
}
