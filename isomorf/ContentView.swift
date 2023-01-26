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
    
    @Published var played: [Int] = []
}

let color0 = Color.white
let color1 = Color.mint
let colorActive = Color.pink

struct Key: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var observable: Observable
    
    @State var diff: Float = 0
    let number: Number
    
    var klass: Int {
        return (number % 12 + 12) % 12
    }
    
    var octave: Int {
        return number / 12
    }
    
    let standardOctave = 5
    var name: String {
        if(standardOctave <= octave) {
            return klass.description + String(repeating: "'", count: Int(octave - standardOctave))
        } else {
            return String(repeating: "'", count: Int(standardOctave - octave)) + klass.description
        }
    }
    
    var isBlack: Bool {
        return [1, 3, 6, 8, 10].map { ($0 + observable.root) % 12 }.contains(klass)
    }
    
    var body: some View {
        let isBlack = isBlack
        let colorFore: Color = isBlack ? color0 : color1
        let colorBack: Color = isBlack ? color1 : color0
        GeometryReader { geometry in
            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorBack)
                    .frame(maxWidth: .infinity)
                
                if(observable.played.contains(number)) {
                    let opacity = Double(abs(diff))
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorActive)
                        .frame(maxWidth: .infinity)
                        .opacity(observable.bends ? opacity : 1)
                } else if(colorScheme == .light && !isBlack) {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color1, lineWidth: 0.5)
                        .frame(maxWidth: .infinity)
                }
                
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(colorFore.opacity(0.4))
                        .frame(width: 3)
                }
                
                Text(name).foregroundColor(colorFore)
            }
        }
    }
}

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var observable = Observable()
    
    var body: some View {
        VStack{
            HStack {
                Toggle("always sustain", isOn: $observable.sustainsAlways)
                Toggle("always bend", isOn: $observable.bendsAlways)
                
                LabeledContent("oct.") {
                    Stepper(
                        onIncrement: { observable.numberLowest += 12 },
                        onDecrement: { observable.numberLowest -= 12 }
                    ) {}
                }
                LabeledContent("min.") {
                    Stepper(
                        onIncrement: { observable.numberLowest += 1 },
                        onDecrement: { observable.numberLowest -= 1 }
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
                LabeledContent("inst.") {
                    Picker("instrument", selection: $observable.instrument) {
                        ForEach(0 ..< 128) { i in
                            Text("\(i)").tag(UInt8.init(i))
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(minHeight: 0)
                    .clipped()
                }
            }
            HStack {
                
            }
        }
        GeometryReader { geometry in
            ZStack {
                HStack(spacing: 1) {
                    let nNotes = observable.nKeys * 2 + 1
                    
                    VStack(spacing: 1) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(observable.bends ? colorActive : color1)
                            Text("bend").foregroundColor(color0)
                        }
                        .frame(width: geometry.size.width / CGFloat(nNotes + 2) * 2)
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(observable.sustains ? colorActive : color0)
                            
                            if(colorScheme == .light && !observable.sustains) {
                                RoundedRectangle(cornerRadius: 8)
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
                                        Rectangle().fill(.clear).frame(width: geometryKeyboard.size.width / CGFloat(nNotes))
                                        
                                        ForEach(0..<observable.nKeys, id: \.self) { i in
                                            Key(number: observable.numberLowest + i * 2 + 1)
                                        }
                                    }
                                    HStack(spacing: 1) {
                                        ForEach(0..<observable.nKeys, id: \.self) { i in
                                            Key(number: observable.numberLowest + i * 2)
                                        }
                                        
                                        Rectangle().fill(.clear).frame(width: geometryKeyboard.size.width / CGFloat(nNotes))
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
}
