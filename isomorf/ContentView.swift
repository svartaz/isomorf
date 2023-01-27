//
//  ContentView.swift
//  isomorf
//
//  Created by sumi on 2023/01/18.
//

import SwiftUI

let tau: Double = Double.pi * 2

func roundEven(_ x: Float) -> Float {
    return round(x / 2) * 2
}

func roundOdd(_ x: Float) -> Float {
    return round((x + 1) / 2) * 2 - 1
}

func between(_ x: Float, min: Float = -.infinity, max: Float = .infinity) -> Bool {
    return min <= x && x < max
}

class Observable: ObservableObject {
    @Published var timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
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
    @Published var nKeys: Int = 11
    @Published var numberLowest: Int = 57
    @Published var instrument: UInt8 = 0 {
        didSet {
            sampler.loadInstrument(instrument)
        }
    }
}

extension Date {
    static func - (a: Date, b: Date) -> TimeInterval {
        return a.timeIntervalSinceReferenceDate - b.timeIntervalSinceReferenceDate
    }
}

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var observable = Observable()
    @State var now = Date()
    
    var body: some View {
        HStack {
            Toggle("sustain", isOn: $observable.sustainsAlways)
            Toggle("bend", isOn: $observable.bendsAlways)
            
            LabeledContent("oct.") {
                Stepper(
                    onIncrement: { observable.numberLowest += 12 },
                    onDecrement: { observable.numberLowest -= 12 }
                ) {}
            }
            LabeledContent("min.") {
                Stepper(
                    onIncrement: { observable.numberLowest += 12 },
                    onDecrement: { observable.numberLowest -= 2 }
                ) {}
            }
            LabeledContent("root") {
                Stepper(value: $observable.root, in: 0...11) {
                    Text("\(observable.root)")
                }
            }
            LabeledContent("col.") {
                Stepper(value: $observable.nKeys, in: 1...24) {
                    Text("\(observable.nKeys)")
                }
            }

            Picker("instrument", selection: $observable.instrument) {
                ForEach(0 ..< 128) { i in
                    Text("\(i) \(generalMidi[i])")
                        .tag(UInt8.init(i))
                        .lineLimit(1, reservesSpace: true)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(minWidth: 200)
        }
        
        GeometryReader { geometry in
            ZStack {
                HStack(spacing: 1) {
                    let nNotes = observable.nKeys * 2 + 1
                    
                    VStack(spacing: 1) {
                        ZStack {
                            RoundedRectangle(cornerRadius: radius)
                                .fill(observable.bends ? colorActive : color1)
                            Text("bend").foregroundColor(color0)
                        }
                        .frame(width: geometry.size.width / CGFloat(nNotes + 2) * 2)
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: radius)
                                .fill(observable.sustains ? colorActive : color0)
                            
                            if(colorScheme == .light && !observable.sustains) {
                                RoundedRectangle(cornerRadius: radius)
                                    .stroke(color1, lineWidth: 0.5)
                            }
                            
                            Text("sustain").foregroundColor(color1)
                        }
                        .frame(width: geometry.size.width / CGFloat(nNotes + 2) * 2)
                    }
                    
                    GeometryReader { geometryKeyboard in
                        ZStack {
                            VStack(spacing: 1) {
                                ForEach(0..<2, id: \.self) { _ in
                                    HStack(spacing: 1) {
                                        Key(observable: observable,
                                            now: $now, isHalf: true, number: observable.numberLowest - 1)
                                        .frame(width: geometryKeyboard.size.width / CGFloat(nNotes))
                                        
                                        ForEach(0..<observable.nKeys, id: \.self) { i in
                                            Key(observable: observable,
                                                now: $now, isHalf: false, number: observable.numberLowest + i * 2 + 1)
                                        }
                                    }
                                    HStack(spacing: 1) {
                                        ForEach(0..<observable.nKeys, id: \.self) { i in
                                            Key(observable: observable,
                                                now: $now, isHalf: false, number: observable.numberLowest + i * 2)
                                        }
                                        
                                        Key(observable: observable,
                                            now: $now, isHalf: true, number: observable.numberLowest + observable.nKeys * 2)
                                        .frame(width: geometryKeyboard.size.width / CGFloat(nNotes))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            TouchRepresentable(observable: observable)
        }
    }
}

