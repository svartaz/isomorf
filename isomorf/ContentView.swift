//
//  ContentView.swift
//  isomorf
//
//  Created by sumi on 2023/01/18.
//

import SwiftUI

let tau: Double = Double.pi * 2

extension Float {
    
}

func roundEven(_ x: Float) -> Float {
    return round(x / 2) * 2
}

func roundOdd(_ x: Float) -> Float {
    return round((x + 1) / 2) * 2 - 1
}

func between(_ x: Float, min: Float = -.infinity, max: Float = .infinity) -> Bool {
    return min <= x && x < max
}

extension Date {
    static func - (a: Date, b: Date) -> TimeInterval {
        return a.timeIntervalSinceReferenceDate - b.timeIntervalSinceReferenceDate
    }
}

enum Layout {
    case janko
    case grid
}

enum Config: String, CaseIterable, Identifiable {
    case janko = "janko"
    case linn4 = "linn (1, 4)"
    case linn = "linn"
    case linn6 = "linn (1, 6)"
    case dodeka = "dodeka"
    case harpejji = "harpejji"
    
    var id: String { rawValue }
}

func chord(_ numbers: [Number]) -> String {
    let numberClasses: Set<Number> = Set(numbers.map { number in
        return number % 12
    })
    
    let patterns = [
        "dim": [0, 3, 6],
        "min": [0, 3, 7],
        "maj": [0, 4, 7],
        "aug": [0, 4, 8],
        
        "sus": [0, 5, 7],
        
        "dim10": [0, 3, 6, 10],
        "dim11": [0, 3, 6, 11],
        "min10": [0, 3, 7, 10],
        "min11": [0, 3, 7, 11],
        "maj10": [0, 4, 7, 10],
        "maj11": [0, 4, 7, 11],
        "aug11": [0, 4, 8, 11],
        
        "min9": [0, 3, 7, 9],
        "maj9": [0, 4, 7, 9],
        "sus10": [0, 5, 7, 10],
        
        "maj13": [0, 4, 8, 11, 1],
        "maj14": [0, 4, 8, 11, 2],
    ]
    
    for (name, pattern) in patterns {
        for root in 0..<12 {
            if(numberClasses == Set(pattern.map { ($0 + root) % 12 })) {
                return "\(root)\(name)"
            }
        }
    }
    
    return ""
}

struct KeyboardView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var observable: Observable
    @State var now = Date()
    @State var geometry: GeometryProxy
    
    var body: some View {
        HStack(spacing: 1) {
            let nNotes = observable.nCols * 2 + 1
            
            VStack(spacing: 1) {
                ZStack {
                    RoundedRectangle(cornerRadius: radius)
                        .fill(observable.bends ? colorActive : color1)
                    Text("bend")
                        .foregroundColor(color0)
                }
                .frame(width: geometry.size.width / CGFloat(nNotes + 2) * 2)
                
                ZStack {
                    RoundedRectangle(cornerRadius: radius)
                        .fill(observable.sustains ? colorActive : color0)
                    
                    if(colorScheme == .light && !observable.sustains) {
                        RoundedRectangle(cornerRadius: radius)
                            .stroke(color1, lineWidth: 0.5)
                    }
                    
                    Text("sustain")
                        .foregroundColor(color1)
                }
                .frame(width: geometry.size.width / CGFloat(nNotes + 2) * 2)
            }
            
            GeometryReader { geometryKeyboard in
                ZStack {
                    VStack(spacing: 1) {
                        ForEach((0..<observable.nRows).reversed(), id: \.self) { i in
                            HStack(spacing: 1) {
                                switch observable.layout {
                                case .janko:
                                    if(i % 2 == 0) {
                                        ForEach(0..<observable.nCols, id: \.self) { j in
                                            Key(observable: observable,
                                                now: $now, isHalf: false, number: observable.numberLowest + j * 2 )
                                        }
                                    } else {
                                        Key(observable: observable,
                                            now: $now, isHalf: true, number: observable.numberLowest - 1)
                                        .frame(width: geometryKeyboard.size.width / CGFloat(nNotes))
                                        
                                        ForEach(0..<(observable.nCols - 1), id: \.self) { j in
                                            Key(observable: observable,
                                                now: $now, isHalf: false, number: observable.numberLowest + j * 2 + 1)
                                        }
                                        
                                        Key(observable: observable,
                                            now: $now, isHalf: true, number: observable.numberLowest + observable.nCols * 2 - 1)
                                        .frame(width: geometryKeyboard.size.width / CGFloat(nNotes))
                                    }
                                case .grid:
                                    ForEach(0..<observable.nCols, id: \.self) { j in
                                        Key(observable: observable,
                                            now: $now, isHalf: false, number: observable.gridNumber(i, j))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}



struct ContentView: View {
    @ObservedObject var observable = Observable()
    
    var body: some View {
        TabView {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    let touched: [Number] = observable.sampler.played
                        .compactMap { (note, value) in
                            let (p, _, _) = value
                            if case .touch(_) = p {
                                return Sampler.toNumber(note)
                            }
                            return nil
                        }
                    
                    Text(chord(touched))
                        .frame(minHeight: 32)

                    ZStack {
                        KeyboardView(observable: observable, geometry: geometry)
                        TouchRepresentable(observable: observable)
                    }
                }
            }
            .tabItem {
                Text("keybaord")
            }
            
            Form {
                Section {
                    Picker("instrument", selection: $observable.instrument) {
                        ForEach(0 ..< 128) { i in
                            Text("\(i) \(generalMidi[i])")
                                .tag(UInt8.init(i))
                                .lineLimit(1, reservesSpace: true)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Toggle("always sustain", isOn: $observable.sustainsAlways)
                    Toggle("always bend", isOn: $observable.bendsAlways)
                } header: {
                    Text("sound")
                }
                
                Section {
                    Picker("preset", selection: $observable.config) {
                        ForEach(Config.allCases) { config in
                            Text(config.rawValue).tag(config)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Picker("layout", selection: $observable.layout) {
                        Text("janko").tag(Layout.janko)
                        Text("grid").tag(Layout.grid)
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    if(observable.layout == .grid) {
                        Stepper("\(observable.gridX) semitones right", value: $observable.gridX)
                        Stepper("\(observable.gridY) semitones up", value: $observable.gridY)
                    }

                    Stepper("\(observable.nCols) columns", value: $observable.nCols, in: 1...24)
                    Stepper("\(observable.nRows) rows", value: $observable.nRows, in: 1...24)

                    Stepper("lowest note \(observable.numberLowest)", value: $observable.numberLowest)
                } header: {
                    Text("layout")
                }
            }
            .tabItem {
                Text("preference")
            }
        }
    }
}

