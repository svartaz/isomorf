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

enum PlayState {
    case touch
    case move
}

enum Discretise {
    case always
    case onTouch
    case never
    
    func on(_ state: PlayState) -> Bool {
        switch state {
        case .touch:
            return self != .never
        case .move:
            return self == .always
        }
    }
}

enum PlayedNote {
    case discrete(Int)
    case continuous(Int, Float)
    
    var number: Int {
        switch self {
        case let .discrete(number):
            return number
        case let .continuous(number, _):
            return number
        }
    }
    
    var numberF: Float {
        switch self {
        case let .discrete(number):
            return Float(number)
        case let .continuous(_, numberF):
            return numberF
        }
    }
    
    var diff: Float {
        switch self {
        case .discrete(_):
            return 0
        case let .continuous(number, numberF):
            return numberF - Float(number)
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

struct Key: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var root: Int
    @Binding var playedNotes: [Int:(PlayedNote, UInt8)]
    let noteNumber: Int
    
    var body: some View {
        let note = Note(noteNumber)
        let isBlack = note.isBlack(root)
        let colorFore: Color = isBlack ? .white : .mint
        let colorBack: Color = isBlack ? .mint : .white
        
        GeometryReader { geometry in
            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorBack)
                    .frame(maxWidth: .infinity)
                
                if let playedNoteMax = (
                    playedNotes
                        .map { (key, value) -> PlayedNote in
                            let (playedNote, _) = value
                            return playedNote
                        }
                        .filter { return note.contains($0.numberF) }
                        .max(by: { (pn, pn1) in
                            return pn.numberF < pn1.numberF
                        })
                ) {
                    let color: Color = {
                        switch playedNoteMax {
                        case .discrete(_): return .pink
                        case .continuous(_, _):
                            let theta = (Double(playedNoteMax.diff) * 2 - 0.5) * tau // -tau/2 ~ tau/2
                            let opacity = (cos(theta) + 1) / 2 * 0.8 + 0.2 // 0.2 ~ 1
                            return .pink.opacity(opacity)
                        }
                    }()
                    
                    RoundedRectangle(cornerRadius: 5)
                        .fill(color)
                        .frame(maxWidth: .infinity)
                }
                
                // border for light theme
                if(colorScheme == .light && !isBlack) {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(.mint, lineWidth: 0.5)
                        .frame(maxWidth: .infinity)
                }
                
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(colorFore.opacity(0.4))
                        .frame(width: 3)
                }
                
                Text(note.name).foregroundColor(colorFore)
            }
        }
    }
}

struct ContentView: View {
    @State var discretise = Discretise.always
    @State var root: Int = 0
    @State var octave: Int = 0
    @State var noteMinKey: Int = 60 - 3
    @State var playedNotes: [Int:(PlayedNote, UInt8)] = [:]
    @State var nKeys: Int = 10
    
    var body: some View {
        VStack{
            HStack{
                LabeledContent("octave:") {
                    Stepper(value: $octave) {
                        Text("\(octave)")
                    }
                }
                LabeledContent("root:") {
                    Stepper(value: $root, in: 0...11) {
                        Text("\(root)")
                    }
                }
                LabeledContent("lowest key:") {
                    Stepper(value: $noteMinKey) {
                        Text("\(Note(noteMinKey).name)")
                    }
                }
                LabeledContent("keys per row:") {
                    Stepper(value: $nKeys, in: 1...24) {
                        Text("\(nKeys)")
                    }
                }
            }
            
            Picker("discretise", selection: $discretise) {
                Text("discrete")
                    .tag(Discretise.always)
                Text("discrete until move")
                    .tag(Discretise.onTouch)
                Text("continuous")
                    .tag(Discretise.never)
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 1) {
                    let nNotes = Float(nKeys * 2 + 1)
                    
                    ForEach(0..<2, id: \.self) { _ in
                        HStack(spacing: 1) {
                            Rectangle().fill(.clear).frame(width: geometry.size.width / CGFloat(nNotes))
                            
                            ForEach(0..<nKeys, id: \.self) { i in
                                Key(root: $root, playedNotes: $playedNotes, noteNumber: i * 2 + 1 + noteMinKey + octave * 12)
                            }
                        }
                        HStack(spacing: 1) {
                            ForEach(0..<nKeys, id: \.self) { i in
                                Key(root: $root, playedNotes: $playedNotes, noteNumber: i * 2 + noteMinKey + octave * 12)
                            }
                            
                            Rectangle().fill(.clear).frame(width: geometry.size.width / CGFloat(nNotes))
                        }
                    }
                }
                
                TouchRepresentable(discretise: $discretise, octave: $octave, noteMinKey: $noteMinKey, playedNotes: $playedNotes, nKeys: $nKeys)
            }
        }
    }
}

struct TouchRepresentable: UIViewRepresentable {
    @Binding var discretise: Discretise
    @Binding var octave: Int
    @Binding var noteMinKey: Int
    @Binding var playedNotes: [Int:(PlayedNote, UInt8)]
    @Binding var nKeys: Int
    
    public func makeUIView(context: UIViewRepresentableContext<TouchRepresentable>) -> TouchView {
        return TouchView(discretise: $discretise, octave: $octave, noteMinKey: $noteMinKey, playedNotes: $playedNotes, nKeys: $nKeys)
    }
    public func updateUIView(_ uiView: TouchView, context: Context) {}
}

class TouchView: UIView, UIGestureRecognizerDelegate {
    let engine = AVAudioEngine()
    let sampler = AVAudioUnitSampler()
    let maxPitchBend: UInt16 = 16384
    
    @Binding var discretise: Discretise
    @Binding var octave: Int
    @Binding var noteMinKey: Int
    @Binding var playedNotes: [Int:(PlayedNote, UInt8)]
    @Binding var nKeys: Int
    
    func isDiscrete(_ state: PlayState) -> Bool {
        return discretise.on(state)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    init(discretise: Binding<Discretise>, octave: Binding<Int>, noteMinKey: Binding<Int>, playedNotes: Binding<[Int:(PlayedNote, UInt8)]>, nKeys: Binding<Int>) {
        self._discretise = discretise
        self._octave = octave
        self._noteMinKey = noteMinKey
        self._playedNotes = playedNotes
        self._nKeys = nKeys
        
        super.init(frame: .zero)
        self.isMultipleTouchEnabled = true
        
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        
        do {
            try engine.start()
        } catch {
            print("engin.start failed")
        }
        
        print("initialised")
    }
    
    deinit {
        if engine.isRunning {
            engine.disconnectNodeOutput(sampler)
            engine.detach(sampler)
            engine.stop()
        }
    }
    
    func numberF(_ location: CGPoint) -> Float {
        let nNoteNumbers = nKeys * 2 + 1
        return Float(location.x) / Float(self.bounds.width) * Float(nNoteNumbers) + Float(noteMinKey - 1 + octave * 12)
    }
    
    func number(_ location: CGPoint) -> Int {
        let isUpper: Bool = between(Float(location.y), max: Float(self.bounds.height) / 4.0) ||
            between(Float(location.y), min: Float(self.bounds.height * 2.0) / 4.0, max: Float(self.bounds.height * 3.0) / 4.0)
        let numberF = numberF(location)
        if(isUpper == (noteMinKey % 2 == 1)) {
            return Int(round(numberF / 2) * 2)
        } else {
            return Int(round((numberF + 1) / 2) * 2 - 1)
        }
    }
    
    func play(_ touch: UITouch, _ playedNote: PlayedNote) {
        if let channelNu = (0...UInt8.max)
            .first(where: {channelNu in
                !playedNotes.values
                    .map{
                        let (_, channel) = $0
                        return channel
                    }
                    .contains(channelNu)
        }) {
            switch playedNote {
            case let .discrete(number):
                sampler.sendPitchBend(0, onChannel: channelNu)
                sampler.startNote(UInt8.init(number), withVelocity: 127, onChannel: channelNu)
                playedNotes.updateValue((PlayedNote.discrete(number), channelNu), forKey: touch.hash)
            case let .continuous(number, numberF):
                break
            }
        } else {
            print("all channels busy")
        }
    }
    
    func bend(_ touch: UITouch, _ noteNumber: Int, noteNumberF: Float) {}
    
    func unplay(_ touch: UITouch) {
        if let (playedNote, channel) = playedNotes[touch.hash] {
            sampler.stopNote(UInt8(playedNote.number), onChannel: channel)
            playedNotes.removeValue(forKey: touch.hash)
        } else {
            print("unplay failed")
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.forEach { touch in
            play(touch, .discrete(number(touch.location(in: self))))
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.forEach { touch in
            let location = touch.location(in: self)
            
            if let (playedNoteOld, channel) = playedNotes[touch.hash] {
                let location = touch.location(in: self)
                if(isDiscrete(.move)) {
                    let number = number(location)

                    if(playedNoteOld.number != number) {
                        unplay(touch)
                        play(touch, .discrete(number))
                    }
                } else {
                    let numberF = numberF(location)
                }
            } else {
                print("move failed")
            }
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.forEach(unplay)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.forEach(unplay)
    }
}
