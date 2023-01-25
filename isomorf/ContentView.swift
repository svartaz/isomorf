//
//  ContentView.swift
//  isomorf
//
//  Created by sumi on 2023/01/18.
//

import SwiftUI
import UIKit
import AudioKit
import SoundpipeAudioKit
import AVFoundation

let tau: Double = Double.pi * 2

extension FloatingPoint {
    func sign() -> Self {
        if self < 0 { return -1 }
        if self > 0 { return 1 }
        return 0
    }
}

func between(_ x: Float, min: Float = -.infinity, max: Float = .infinity) -> Bool {
    return min <= x && x < max
}

enum PlayedNote {
    case discrete(Int)
    case continuous(Float)
    
    var number: Int {
        switch self {
        case let .discrete(number):
            return number
        case let .continuous(numberF):
            return Int(round(numberF))
        }
    }
    
    var numberF: Float {
        switch self {
        case let .discrete(number):
            return Float(number)
        case let .continuous(numberF):
            return numberF
        }
    }
    
    var frac: Float {
        switch self {
        case .discrete(_):
            return 0
        case let .continuous(numberF):
            return numberF - round(numberF)
        }
    }
}

struct Note {
    var number: Int
    
    init(_ noteNumber: Int) {
        self.number = noteNumber
    }
    
    init(_ noteNumberF: Float) {
        self.number = Int(round(noteNumberF))
    }
    
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
    
    func isBlack(_ root: Int) -> Bool {
        return [1, 3, 6, 8, 10].map { ($0 + root) % 12 }.contains(klass)
    }
    
    func contains(_ noteNumberF: Float) -> Bool {
        return Int(round(noteNumberF)) == number
    }
}

extension CGPoint: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
}

class Sampler {
    var engine = AVAudioEngine()
    var sampler = AVAudioUnitSampler()
    var notesPlayed: [UUID: (PlayedNote, UInt8, UInt8)] = [:]
    var notesSustained: Set<UUID> = []
    let maxPitchBend: Int = 16384
    let maxNoteBend: Int = 4
    
    var channelsUsed: [UInt8] {
        return notesPlayed.map { (_, value) in
            let (_, _, channel) = value
            return channel
        }
    }
    
    init() {
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        
        loadInstrument(0)
        
        do {
            try engine.start()
        } catch {
            print("falied to start engin")
        }
    }
    
    func pitchBend(_ x: Float) -> UInt16 {
        let pitchBendF: Float = Float(maxPitchBend) / Float(maxNoteBend) * (2 * x + 1)
        return UInt16.init(Int(pitchBendF))
    }
    
    func play(_ id: UUID, _ number: Int) {
        for channel: UInt8 in 0..<128 {
            if(!channelsUsed.contains(channel)) {
                let pitchBend: UInt16 = .init(maxPitchBend / 2)
                sampler.sendPitchBend(pitchBend, onChannel: channel)

                let note: UInt8 = .init(number - 2)
                sampler.startNote(note, withVelocity: 127, onChannel: channel)
                notesPlayed[id] = (PlayedNote.discrete(number), note, channel)
                return
            }
        }
        print("failed to play")
    }
    
    func play(_ id: UUID, _ number: Int, _ x: Float) {
        for channel: UInt8 in 0..<128 {
            if(!channelsUsed.contains(channel)) {
                let note: UInt8 = .init(number - 2)
                sampler.sendPitchBend(pitchBend(x), onChannel: channel)
                sampler.startNote(note, withVelocity: 127, onChannel: channel)
                notesPlayed[id] = (PlayedNote.discrete(number), note, channel)
                return
            }
        }
        print("failed to play")
    }
    
    func unplay(_ id: UUID) {
        if let (_, note, channel) = notesPlayed[id] {
            sampler.stopNote(note, onChannel: channel)
            notesPlayed.removeValue(forKey: id)
        } else {
            print("failed to unplay")
        }
    }
    
    func bend(_ id: UUID, _ x: Float) {
        if let (_, _, channel) = notesPlayed[id] {
            sampler.sendPitchBend(pitchBend(x), onChannel: channel)
        } else {
            print("failed to bend")
        }
    }
    
    func unbend() {
        for channel in channelsUsed {
            sampler.sendPitchBend(UInt16.init(maxPitchBend / 2), onChannel: channel)
        }
    }
    
    func sustain(_ id: UUID) {
        notesSustained.insert(id)
    }
    
    func unsustain() {
        for id in notesSustained {
            unplay(id)
        }
        notesSustained = []
    }
    
    func loadInstrument(_ instrument: UInt8) {
        if let url = Bundle.main.url(forResource: "SGM-V2.01", withExtension: "sf2"),
           let _ = try? sampler.loadSoundBankInstrument(
            at: url, program: instrument,
            bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
            bankLSB: UInt8(kAUSampler_DefaultBankLSB))
        {
            print("instrument \(instrument) loaded")
        } else {
            print("locadSoundBankInstrument failed")
        }
    }
}

let color0 = Color.white
let color1 = Color.mint
let colorActive = Color.pink

struct Key: View {
    @Environment(\.colorScheme) var colorScheme
    @State var id = UUID()
    @Binding var sampler: Sampler
    @Binding var sustainsAlways: Bool
    @Binding var sustainsCurrently: Bool
    @Binding var bendsAlways: Bool
    @Binding var bendsCurrently: Bool
    @Binding var root: Int
    @State var isPlayed = false
    @State var isSustained = false
    @State var x: Float = 0.5
    let number: Int

    var body: some View {
        let note = Note(number)
        let isBlack = note.isBlack(root)
        let colorFore: Color = isBlack ? color0 : color1
        let colorBack: Color = isBlack ? color1 : color0
        GeometryReader { geometry in
            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorBack)
                    .frame(maxWidth: .infinity)
                
                if(isPlayed) {
                    let opacity: Double = 1 - abs(Double(x) - 0.5)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorActive)
                        .frame(maxWidth: .infinity)
                        .opacity(bendsAlways || bendsCurrently ? opacity : 1)
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
                
                Text(note.name).foregroundColor(colorFore)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged() { action in
                        if(action.startLocation == action.location) {
                            // begin
                            
                            if(bendsAlways || bendsCurrently) {
                                sampler.play(id, number, x)
                            } else {
                                sampler.play(id, number)
                            }
                            isPlayed = true
                        } else {
                            // move
                            
                            x = Float(action.location.x / geometry.size.width)
                            let y = Float(action.location.y / geometry.size.height)
                            
                            if(between(x, min: 0, max: 1) && between(y, min: 0, max: 1)) {
                                if(bendsAlways || bendsCurrently) {
                                    sampler.bend(id, x)
                                }
                            } else {
                                sampler.unplay(id)
                                isPlayed = false
                            }
                        }
                    }.onEnded() { value in
                        if(sustainsAlways || sustainsCurrently) {
                            sampler.sustain(id)
                            isSustained = true
                        } else {
                            sampler.unplay(id)
                            isPlayed = false
                        }
                    }
            )
        }
    }
}

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @State var bendsAlways = false
    @State var bendsCurrently = false
    @State var sustainsAlways = false
    @State var sustainsCurrently = false
    @State var sampler: Sampler = Sampler()
    @State var root: Int = 0
    @State var octave: Int = 0
    @State var noteMinKey: Int = 60 - 3
    @State var nKeys: Int = 10
    @State var instrument: UInt8 = 0
    
    var bends: Bool {
        return bendsAlways || bendsCurrently
    }
    
    var sustains: Bool {
        return sustainsAlways || sustainsCurrently
    }
    
    var body: some View {
        VStack{
            HStack {
                Toggle("always sustain", isOn: $sustainsAlways)
                
                Toggle("always bend", isOn: $bendsAlways)
                
                LabeledContent("oct.") {
                    Stepper(value: $octave) {
                        Text("\(octave)")
                    }
                }
                LabeledContent("min.") {
                    Stepper(value: $noteMinKey) {
                        Text("\(Note(noteMinKey).name)")
                    }
                }
                LabeledContent("root") {
                    Stepper(value: $root, in: 0...11) {
                        Text("\(root)")
                    }
                }
                LabeledContent("col.") {
                    Stepper(value: $nKeys, in: 1...24) {
                        Text("\(nKeys)")
                    }
                }
                LabeledContent("inst.") {
                    Picker("instrument", selection: $instrument) {
                        ForEach(0 ..< 128) { i in
                            Text("\(i)").tag(UInt8.init(i))
                        }
                    }
                    .onChange(of: instrument) { _ in
                        sampler.loadInstrument(instrument)
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
            HStack(spacing: 1) {
                let nNotes = nKeys * 2 + 1
                
                VStack(spacing: 1) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(bends ? colorActive : color1)
                        Text("bend").foregroundColor(color0)
                    }
                    .frame(width: geometry.size.width / CGFloat(nNotes + 2) * 2)
                    .simultaneousGesture(DragGesture(minimumDistance: 0)
                        .onChanged() { _ in
                            bendsCurrently = true
                        }
                        .onEnded() { _ in
                            bendsCurrently = false
                            sampler.unbend()
                        }
                    )
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(sustains ? colorActive : color0)
                        
                        if(colorScheme == .light && !sustains) {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(color1, lineWidth: 0.5)
                        }
                        
                        Text("sustain").foregroundColor(color1)
                    }
                    .frame(width: geometry.size.width / CGFloat(nNotes + 2) * 2)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged() { _ in
                                sustainsCurrently = true
                            }
                            .onEnded() { _ in
                                sustainsCurrently = false
                                if(!sustains) {
                                    sampler.unsustain()
                                }
                            }
                    )
                }
                
                GeometryReader { geometryKeyboard in
                    ZStack {
                        VStack(spacing: 1) {
                            
                            ForEach(0..<2, id: \.self) { _ in
                                HStack(spacing: 1) {
                                    Rectangle().fill(.clear).frame(width: geometryKeyboard.size.width / CGFloat(nNotes))
                                    
                                    ForEach(0..<nKeys, id: \.self) { i in
                                        Key(sampler: $sampler,
                                            sustainsAlways: $sustainsAlways, sustainsCurrently: $sustainsCurrently,
                                            bendsAlways: $bendsAlways, bendsCurrently: $bendsCurrently,
                                            root: $root, number: i * 2 + 1 + noteMinKey + octave * 12)
                                    }
                                }
                                HStack(spacing: 1) {
                                    ForEach(0..<nKeys, id: \.self) { i in
                                        Key(sampler: $sampler,
                                            sustainsAlways: $sustainsAlways, sustainsCurrently: $sustainsCurrently,
                                            bendsAlways: $bendsAlways, bendsCurrently: $bendsCurrently,
                                            root: $root, number: i * 2 + noteMinKey + octave * 12)
                                    }
                                    
                                    Rectangle().fill(.clear).frame(width: geometryKeyboard.size.width / CGFloat(nNotes))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
