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

func between(_ x: Float, min: Float = -.infinity, max: Float = .infinity) -> Bool {
    return min <= x && x < max
}

extension Date {
    static func - (a: Date, b: Date) -> TimeInterval {
        return a.timeIntervalSinceReferenceDate - b.timeIntervalSinceReferenceDate
    }
}

enum Layout: String, CaseIterable, Identifiable {
    case janko = "janko"
    case wicki = "wicki-hayden"
    case harmonic = "harmonic"
    case linn = "linnstrument"
    case harpejji = "harpejji"
    case dodeka = "dodeka"

    var id: String { rawValue }
}

enum Align: String, CaseIterable, Identifiable {
    case rect = "rectangle"
    case hex = "hexagon"
    
    var id: String { rawValue }
}

struct KeyboardMainView: View {
    @ObservedObject var observable: Observable
    @State var now = Date()
    @State var geometry: GeometryProxy
    
    var body: some View {
        let widthHalf: CGFloat = geometry.size.width / CGFloat(observable.nCols) / CGFloat(2)
        
        VStack(spacing: 1) {
            ForEach((0..<observable.nRows).reversed(), id: \.self) { i in
                HStack(spacing: 1) {
                    if(i % 2 == 0 || observable.align == .rect) {
                        ForEach(0..<observable.nCols, id: \.self) { j in
                            Key(observable: observable,
                                now: $now, isHalf: false, number: observable.number(i, j))
                        }
                    } else {
                        Key(observable: observable, now: $now, isHalf: true, number: observable.number(i, -1))
                            .frame(width: widthHalf)
                        
                        let jMax: Int = observable.nCols - 1
                        ForEach(0..<jMax, id: \.self) { j in
                            Key(observable: observable,
                                now: $now, isHalf: false, number: observable.number(i, j))
                        }
                        
                        Key(observable: observable, now: $now, isHalf: true, number: observable.number(i, jMax))
                            .frame(width: widthHalf)
                    }
                }
            }
        }
    }
}

struct KeyboardView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var observable: Observable
    @State var now = Date()
    @State var geometry: GeometryProxy
    
    var body: some View {
        HStack(spacing: 1) {
            let nNumbers = observable.nCols * 2 + 1
            
            VStack(spacing: 1) {
                ZStack {
                    RoundedRectangle(cornerRadius: radius)
                        .fill(observable.bends ? colorActive : color1)
                    Text("bend")
                        .foregroundColor(color0)
                }
                .frame(width: geometry.size.width / CGFloat(nNumbers + 2) * 2)
                
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
                .frame(width: geometry.size.width / CGFloat(nNumbers + 2) * 2)
            }
            
            GeometryReader { geometryKeyboard in
                KeyboardMainView(observable: observable, geometry: geometryKeyboard)
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
            ("min", "m", [0, 3]),
            ("maj", "M", [0, 4]),
            
            ("dim", "dim", [0, 3, 6]),
            ("min", "m", [0, 3, 7]),
            ("maj", "", [0, 4, 7]),
            ("aug", "aug", [0, 4, 8]),
            
            ("min3", "m7", [0, 3, 7, 10]),
            ("min4", "mM7", [0, 3, 7, 11]),
            ("maj3", "7", [0, 4, 7, 10]),
            ("maj4", "M7", [0, 4, 7, 11]),
            
            ("dim3", "dim7", [0, 3, 6, 9]),
            ("dim4", "m7-5", [0, 3, 6, 10]),
            ("maj3-6", "7-5", [0, 4, 6, 10]),
            ("aug3", "M7+5", [0, 4, 8, 11]),
            
            ("min3,3", "m-9", [0, 3, 10, 1]),
            ("min3,4", "m9", [0, 3, 10, 2]),
            ("maj3,3", "-9", [0, 4, 10, 1]),
            ("maj3,4", "9", [0, 4, 10, 2]),
            
            ("min3,3", "m-9", [0, 3, 7, 10, 1]),
            ("min3,4", "m9", [0, 3, 7, 10, 2]),
            ("maj3,3", "-9", [0, 4, 7, 10, 1]),
            ("maj3,4", "9", [0, 4, 7, 10, 2]),
            
            ("sus", "sus4", [0, 5, 7]),
            ("sus3", "7sus4", [0, 5, 7, 10])
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
                        .compactMap { (p: Play, v) in
                            let (number, _, _) = v
                            if case .touch(_) = p {
                                return number
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
                    
                    if(observable.sampler.url != nil) {
                        Picker("instrument", selection: $observable.instrument) {
                            ForEach(0 ..< 128) { i in
                                Text("\(i) \(generalMidi[i])")
                                    .tag(UInt8.init(i))
                                    .lineLimit(1, reservesSpace: true)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    
                    Toggle("always sustain", isOn: $observable.sustainsAlways)
                    Toggle("always bend", isOn: $observable.bendsAlways)
                } header: {
                    Text("sound")
                }
                
                Section {
                    Picker("layout", selection: $observable.layout) {
                        ForEach(Layout.allCases) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Picker("align", selection: $observable.align) {
                        ForEach(Align.allCases) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Stepper(value: $observable.gridX, in: 1...24) {
                        Text("pitch to right \(observable.gridX)")
                    }
                    Stepper(value: $observable.gridY, in: 1...24) {
                        Text("pitch to top: \(observable.gridY)")
                    }
                    
                    Stepper(value: $observable.nCols, in: 1...24) {
                        Text("columns: \(observable.nCols)")
                    }
                    Stepper(value: $observable.nRows, in: 1...24) {
                        Text("rows: \(observable.nRows)")
                    }
                    
                    Stepper("lowest note: \( observable.numberLowest)", value: $observable.numberLowest)
                } header: {
                    Text("layout")
                }
                
                Section {
                    Toggle("colour black keys", isOn: $observable.coloursBlack)
                    if(observable.coloursBlack) {
                        Stepper(value: $observable.root) {
                            Text("root: \(observable.root)")
                        }
                    }
                    
                    Toggle("traditional", isOn: $observable.isTraditional)
                } header: {
                    Text("appearance")
                }

            }
            .tabItem {
                Text("preference")
            }
        }
    }
}

