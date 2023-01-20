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

extension FloatingPoint {
    @inlinable
    func signum( ) -> Self {
        if self < 0 { return -1 }
        if self > 0 { return 1 }
        return 0
    }
}

func between(_ x: Float, min: Float = -.infinity, max: Float = .infinity) -> Bool {
    return min <= x && x < max
}

enum DragState {
    case stay
    case move
    
    var toString: String {
        switch self {
        case .stay:
            return "stay"
        case .move:
            return "move"
        }
    }
}

enum Discrete: String, CaseIterable, Identifiable {
    var id: String{ self.rawValue }
    case always
    case initially
    case never
}

enum Tuning {
    case scientific
    case orchestral
    
    var cPerSec: Float {
        switch self {
        case .scientific:
            return 256
        case .orchestral:
            return 440.0 / pow(2.0, 9.0 / 12.0)
        }
    }
}

func toneName(_ tone: Int) -> String {
    let toneClass = ((tone % 12) + 12) % 12
    let octave = Int(floor(Float(tone) / 12.0))
    if(octave < 0) {
        return String(repeating: "'", count: abs(octave)) + toneClass.description
    } else {
        return toneClass.description + String(repeating: "'", count: octave)
    }
}

struct Key: View {
    let root: Int
    let tone: Int
    @Binding var tones: [Float]
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        let toneClass: Int = ((tone % 12) + 12) % 12
        let isBlack: Bool = [1, 3, 6, 8, 10].map { x in (x + root) % 12 }.contains(toneClass)
        
        let colorFore: Color = isBlack ? .white : .mint
        let colorBack: Color = tones
            .filter { between($0, min: Float(tone) - 0.5, max: Float(tone) + 0.5) }
            .max()
            .map { _ in .pink } ?? (isBlack ? .mint : .white)
        
        GeometryReader { geometry in
            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(colorBack)
                    .frame(maxWidth: .infinity)
                    .overlay(Text(toneName(tone)).foregroundColor(colorFore))
                
                if(colorScheme == .light && !isBlack) {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(.mint, lineWidth: 0.5)
                        .frame(maxWidth: .infinity)
                }
                
                HStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(colorFore.opacity(0.4))
                        .frame(width: 3)
                    Spacer()
                }
            }
        }
    }
}

struct ContentView: View {
    @State var discrete = Discrete.always
    @State var tuning = Tuning.scientific
    @State var root = 0
    @State var octave = 0
    @State var toneMinKey: Int = -3
    @State var tones: [Float] = []
    @State var numKey: Int = 10
    
    var body: some View {
        VStack{
            HStack{
                Picker("tuning", selection: $tuning) {
                    Text("C4=256/s").tag(Tuning.scientific)
                    Text("A4=440/s").tag(Tuning.orchestral)
                }
                .pickerStyle(SegmentedPickerStyle())
                
                LabeledContent("discrete:") {
                    Picker("discretise", selection: $discrete) {
                        ForEach(Discrete.allCases, id: \.self) { value in
                            Text(value.rawValue)
                                .tag(value)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
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
                    Stepper(value: $toneMinKey) {
                        Text("\(toneName(toneMinKey))")
                    }
                }
                LabeledContent("keys per row:") {
                    Stepper(value: $numKey, in: 1...24) {
                        Text("\(numKey)")
                    }
                }
            }
            
        }
        
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 1) {
                    ForEach(0..<2, id: \.self) { _ in
                        let nTone = Float(numKey * 2 + 1)
                        
                        HStack(spacing: 1) {
                            Rectangle().fill(.clear).frame(width: geometry.size.width / CGFloat(nTone))
                            
                            ForEach(0..<numKey, id: \.self) { i in
                                Key(root: root, tone: i * 2 + 1 + toneMinKey + octave * 12, tones: $tones)
                            }
                        }
                        HStack(spacing: 1) {
                            ForEach(0..<numKey, id: \.self) { i in
                                Key(root: root, tone: i * 2 + toneMinKey + octave * 12, tones: $tones)
                            }
                            
                            Rectangle().fill(.clear).frame(width: geometry.size.width / CGFloat(nTone))
                        }
                    }
                }
                
                TouchRepresentable(discrete: $discrete, tuning: $tuning, octave: $octave, toneMinKey: $toneMinKey, tones: $tones, numKey: $numKey)
            }
        }
    }
}

struct TouchRepresentable: UIViewRepresentable {
    @Binding var discrete: Discrete
    @Binding var tuning: Tuning
    @Binding var octave: Int
    @Binding var toneMinKey: Int
    @Binding var tones: [Float]
    @Binding var numKey: Int
    @State var oscillators: NSMutableDictionary = [:]
    
    
    typealias Context = UIViewRepresentableContext<TouchRepresentable>
    public func makeUIView(context: Context) -> TouchView { return TouchView(discrete: $discrete, tuning: $tuning, octave: $octave, toneMinKey: $toneMinKey, tones: $tones, numKey: $numKey) }
    public func updateUIView(_ uiView: TouchView, context: Context) {}
}

class TouchView: UIView, UIGestureRecognizerDelegate {
    let engine = AudioEngine()
    let mixer = Mixer()
    
    @Binding var discrete: Discrete
    @Binding var tuning: Tuning
    @Binding var octave: Int
    @Binding var toneMinKey: Int
    @Binding var tones: [Float]
    @Binding var numKey: Int
    @State var oscillators: NSMutableDictionary = [:]
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    init(discrete: Binding<Discrete>, tuning: Binding<Tuning>, octave: Binding<Int>, toneMinKey: Binding<Int>, tones: Binding<[Float]>, numKey: Binding<Int>) {
        self._discrete = discrete
        self._tuning = tuning
        self._octave = octave
        self._toneMinKey = toneMinKey
        self._tones = tones
        self._numKey = numKey
        
        super.init(frame: .zero)
        self.isMultipleTouchEnabled = true
        
        engine.output = mixer
        do {
            print("start engine")
            try engine.start()
        } catch let error {
            print(error)
        }
        
        print("initialised")
    }
    
    func tone(location: CGPoint, state: DragState) -> Float {
        let nTone = Float(numKey * 2 + 1)
        let tone = Float(location.x) / Float(self.bounds.width) * nTone + Float(toneMinKey - 1)
        
        let toneFloor = floor(tone)
        let isUpper = between(Float(location.y), max: Float(self.bounds.height) / 4.0)
        || between(Float(location.y), min: Float(self.bounds.height * 2.0) / 4.0, max: Float(self.bounds.height * 3.0) / 4.0)
        
        let diff = (toneMinKey % 12 + 12 + (isUpper ? 1 : 0)) % 2
        let toneJust = toneFloor + Float(abs(Int(round(toneFloor + Float(diff))) % 2))
        
        switch state {
        case .stay:
            return (discrete == .never ? tone : toneJust) + Float(octave * 12)
        case .move:
            return (discrete == .always ? toneJust : tone) + Float(octave * 12)
        }
    }
    
    func frequency(_ tone: Float) -> Float {
        return tuning.cPerSec * pow(2.0, tone / 12.0)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.forEach { touch in
            let location = touch.location(in: self)
            let tone = tone(location: location, state: .stay)
            
            let oscillator = DynamicOscillator(
                waveform: Table(.sine),
                frequency: frequency(tone),
                amplitude: 0)
            mixer.addInput(oscillator)
            oscillator.start()
            oscillator.$amplitude.ramp(to: 1, duration: 0.01)
            oscillators[touch.hash] = (oscillator, tone, DragState.stay)
        }
        print("\(oscillators)")
        update()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.forEach { touch in
            let location = touch.location(in: self)
            let tone = tone(location: location, state: .move)
            if let (oscillator, _, _) = oscillators[touch.hash] as? (DynamicOscillator, Float, DragState) {
                oscillator.frequency = frequency(tone)
                oscillators[touch.hash] = (oscillator, tone, DragState.move)
            }
        }
        print("\(oscillators)")
        update()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        stop(touches)
        print("\(oscillators)")
        update()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        stop(touches)
        print("\(oscillators)")
        update()
    }
    
    func stop(_ touches: Set<UITouch>) {
        touches.forEach { touch in
            if let (oscillator, _, _) = oscillators[touch.hash] as? (DynamicOscillator, Float, DragState) {
                oscillator.$amplitude.ramp(to: 0, duration: 0.01)
                self.oscillators.removeObject(forKey: touch.hash)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [self] in
                    oscillator.stop()
                    self.mixer.removeInput(oscillator)
                }
            } else {
                print("stop failed")
            }
        }
    }
    
    func update() {
        tones = oscillators.compactMap { (key, value) in
            if let (_, t, _) = value as? (DynamicOscillator, Float, DragState) {
                return t
            } else {
                return nil
            }
        }
    }
}
