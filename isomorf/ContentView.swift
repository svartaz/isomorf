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
        VStack {
            HStack {
                Picker("layout", selection: $observable.layout) {
                    Text("janko").tag(Layout.janko)
                    Text("grid").tag(Layout.grid)
                }
                .pickerStyle(SegmentedPickerStyle())

                Picker("config", selection: $observable.config) {
                    ForEach(Config.allCases) { config in
                        Text(config.rawValue).tag(config)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                LabeledContent("grid: (\(observable.gridX),\(observable.gridY))") {
                    Stepper("", value: $observable.gridX)
                    Stepper("", value: $observable.gridY)
                }
                 
                LabeledContent("(col,row): (\(observable.nCols),\(observable.nRows))") {
                    Stepper("", value: $observable.nCols, in: 1...24)
                    Stepper("", value: $observable.nRows, in: 1...24)
                }
            }
            
            HStack {
                Toggle("sustain", isOn: $observable.sustainsAlways)
                Toggle("bend", isOn: $observable.bendsAlways)
                
                Spacer()
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
                
                Spacer()
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
        }
        
        GeometryReader { geometry in
            ZStack {
                KeyboardView(observable: observable, geometry: geometry)
                TouchRepresentable(observable: observable)
            }
        }
    }
}

