//
//  Key.swift
//  isomorf
//
//  Created by sumi on 2023/01/28.
//

import SwiftUI

let color0 = Color.white
let color1 = Color.mint
let colorActive = Color.pink

let radius = CGFloat(8.0)

struct Key: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var observable: Observable
    @Binding var now: Date
    
    let isHalf: Bool
    let number: Number
    
    var klass: Int {
        return (number % 12 + 12) % 12
    }
    
    var octave: Int {
        return number / 12
    }
    
    var name: String {
        let standardOctave = 5
        
        if(observable.isTraditional) {
            return "\(["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"][klass])\(octave - standardOctave + 4)"
        } else {
            if(standardOctave <= octave) {
                return klass.description + String(repeating: "'", count: Int(octave - standardOctave))
            } else {
                return String(repeating: "'", count: Int(standardOctave - octave)) + klass.description
            }
        }
    }
    
    var isBlack: Bool {
        return [1, 3, 6, 8, 10].map { ($0 + observable.root) % 12 }.contains(klass)
    }
    
    var body: some View {
        let colorFore: Color = isBlack ? color0 : color1
        let colorBack: Color = isBlack ? color1 : color0
        
        ZStack(alignment: .center) {
            RoundedRectangle(cornerRadius: radius)
                .fill(colorBack)
                .frame(maxWidth: .infinity)
            
            let opacity: Double = {
                let dates = observable.sampler.played.compactMap { (p: Play, v) in
                    if case let .sustain(date) = p {
                        let (n, _, _) = v
                        if(number == n) {
                            return date
                        }
                    }
                    return nil
                }
                
                if let date = dates.min() {
                    let minOpacity = 0.4
                    return (1.0 - min(1, now - date)) * (1 - minOpacity) + minOpacity
                } else {
                    for (p, v) in observable.sampler.played {
                        if case .touch(_) = p {
                            let (n, _, _) = v
                            if(number == n) {
                                return 1
                            }
                        }
                    }
                    
                    return 0
                }
            }()
            
            let diff: Float = observable.sampler.played.compactMap { (p: Play, v) in
                let (n, _, diff) = v
                if(number == n) {
                    return diff
                } else {
                    return nil
                }
            }
            .max() ?? Float(0)
            
            RoundedRectangle(cornerRadius: radius)
                .fill(colorActive)
                .frame(maxWidth: .infinity)
                .opacity(opacity)
                .saturation(1 - abs(Double(diff * 2.0 / Float(observable.gridX))))
                .onReceive(observable.timer, perform: { _ in
                    now = Date()
                })
            
            if(colorScheme == .light) {
                RoundedRectangle(cornerRadius: radius)
                    .stroke(color1, lineWidth: 0.5)
                    .frame(maxWidth: .infinity)
            }
            
            if(!isHalf) {
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
