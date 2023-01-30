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
    @State var isPresented = false
    
    func chord(_ numbers: [Number]) -> String {
        let numberClasses: Set<Number> = Set(numbers.map { number in
            return number % 12
        })
        
        let patterns = [
            ("dim", "dim", [0, 3, 6]),
            ("dim9", "dim7", [0, 3, 6, 9]),
            ("min6!", "m7-5", [0, 3, 6, 10]),

            ("min", "m", [0, 3, 7]),
            ("min10", "m7", [0, 3, 7, 10]),
            ("min11", "mM7", [0, 3, 7, 11]),

            ("maj", "", [0, 4, 7]),
            ("maj6!,10", "7-5", [0, 4, 6, 10]),
            ("maj10", "7", [0, 4, 7, 10]),
            ("maj11", "M7", [0, 4, 7, 11]),
            ("maj10,13", "-9", [0, 4, 7, 10, 1]),
            ("maj10,14", "9", [0, 4, 7, 10, 2]),

            ("aug", "aug", [0, 4, 8]),
            ("aug11", "M7+5", [0, 4, 8, 11]),

            ("sus", "sus4", [0, 5, 7]),
            ("sus10", "7sus4", [0, 5, 7, 10])
        ]
        
        for (name, nameTraditional, pattern) in patterns {
            for root in 0..<12 {
                if(numberClasses == Set(pattern.map { ($0 + root) % 12 })) {
                    if(observable.isTraditional) {
                        return "\(["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"][root])\(nameTraditional)"
                    } else {
                        return "\(root)\(name)"
                    }
                }
            }
        }
        
        return ""
    }
    
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
                    LabeledContent("sound font") {
                        if let url = observable.sampler.url {
                            Text(url.description)
                        }
                        Button("load") {
                            isPresented = true
                        }
                        .buttonStyle(.bordered)
                        .fileImporter(isPresented: $isPresented, allowedContentTypes: [.audio], allowsMultipleSelection: false) {
                            switch $0 {
                            case .success(let urls):
                                observable.sampler.url = urls.first
                                print("View set url")
                                observable.sampler.loadInstrument()
                            case .failure:
                                print("View failed to set url")
                            }
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
                        Stepper("semitones right: \(observable.gridX)", value: $observable.gridX)
                        Stepper("semitones up: \(observable.gridY)", value: $observable.gridY)
                    }

                    Stepper(value: $observable.nCols, in: 1...24) {
                        Text("columns: \(observable.nCols)")
                    }
                    Stepper(value: $observable.nRows, in: 1...24) {
                        Text("rows: \(observable.nRows)")
                    }

                    Stepper("lowest note: \(observable.numberLowest)", value: $observable.numberLowest)

                    Toggle("traditional", isOn: $observable.isTraditional)
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

