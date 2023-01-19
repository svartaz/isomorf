//
//  ContentView.swift
//  isomorf
//
//  Created by sumi on 2023/01/18.
//

import SwiftUI
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

enum DragState {
    case wait
    case stay
    case move
    
    var toString: String {
        switch self {
        case .wait:
            return "wait"
        case .stay:
            return "stay"
        case .move:
            return "move"
        }
    }
}

struct ContentView: View {
    @State var engine = AudioEngine()
    @State var oscillator = DynamicOscillator(waveform: Table(.sine), frequency: 440, amplitude: 1)
    @State var location: CGPoint = .zero
    @State var state: DragState = .wait
    
    let cHz: Float = 256.0
    
    var body: some View {
        Text("(\(location.x), \(location.y))")
        Text("\(oscillator.frequency) /s")
        Text("\(log2(oscillator.frequency / 256) * 12)")
        Text(state.toString)
        GeometryReader { geometry in
            VStack(spacing: 1) {
                HStack(spacing: 1) {
                    Rectangle().fill(.clear).frame(width: geometry.size.width / 13.0)
                    
                    Rectangle().fill(.pink).frame(maxWidth: .infinity)
                    Rectangle().fill(.pink).frame(maxWidth: .infinity)
                    Rectangle().fill(.cyan).frame(maxWidth: .infinity)
                    Rectangle().fill(.cyan).frame(maxWidth: .infinity)
                    Rectangle().fill(.cyan).frame(maxWidth: .infinity)
                    Rectangle().fill(.cyan).frame(maxWidth: .infinity)
                }
                HStack(spacing: 1) {
                    Rectangle().fill(.cyan).frame(maxWidth: .infinity)
                    Rectangle().fill(.cyan).frame(maxWidth: .infinity)
                    Rectangle().fill(.cyan).frame(maxWidth: .infinity)
                    Rectangle().fill(.pink).frame(maxWidth: .infinity)
                    Rectangle().fill(.pink).frame(maxWidth: .infinity)
                    Rectangle().fill(.pink).frame(maxWidth: .infinity)
                    
                    Rectangle().fill(.clear).frame(width: geometry.size.width / 13.0)
                }
            }
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("rect"))
                .onChanged { value in
                    location = value.location
                    let x = Float(value.location.x) / Float(geometry.size.width) * 13 - 1
                    
                    switch state {
                    case .wait:
                        state = .stay
                        
                        let xFloor = floor(x)
                        let xJust = location.y < geometry.size.height / 2.0 ?
                        xFloor + Float(abs(Int(round(xFloor + 1)) % 2)) :
                        xFloor + Float(abs(Int(round(xFloor)) % 2))
                        oscillator.frequency = cHz * pow(2.0, xJust / 12.0)
                        
                        engine.output = oscillator
                        oscillator.start()
                        
                        do {
                            print("start")
                            try engine.start()
                        } catch let error {
                            print(error)
                        }
                    case .stay, .move:
                        state = .move
                        oscillator.frequency = cHz * pow(2.0, x / 12.0)
                    }
                }
                .onEnded { _ in
                    state = .wait
                    oscillator.stop()
                }
            )
        }
        .coordinateSpace(name: "rect")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
