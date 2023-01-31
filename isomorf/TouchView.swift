//
//  TouchView.swift
//  isomorf
//
//  Created by sumi on 2023/01/27.
//

import SwiftUI
import UIKit

struct TouchRepresentable: UIViewRepresentable {
    @ObservedObject var observable: Observable
    
    public func makeUIView(context: UIViewRepresentableContext<TouchRepresentable>) -> TouchView {
        return TouchView(observable: observable)
    }
    public func updateUIView(_ uiView: TouchView, context: Context) {}
}

enum TouchState: Equatable {
    case bend
    case sustain
    case key(Number, Float)
}

class TouchView: UIView, UIGestureRecognizerDelegate {
    let maxPitchBend: UInt16 = 16384
    
    var touchStates: [Int:TouchState] = [:]
    @ObservedObject var observable: Observable
    
    init(observable: Observable) {
        self.observable = observable
        
        super.init(frame: .zero)
        self.isMultipleTouchEnabled = true
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    func touchState(_ touch: UITouch) -> TouchState {
        let width = Float(self.bounds.width)
        let height = Float(self.bounds.height)
        let widthKey = width / ((Float(observable.nCols) + 1) * 2 + 1) * 2
        let location = touch.location(in: self)
        let x = Float(location.x)
        let y = Float(location.y)
        
        if(x < widthKey) {
            if(y < height / 2) {
                return .bend
            } else {
                return .sustain
            }
        } else {
            let iF = (height - y) / height * Float(observable.nRows) - 0.5
            let i = Int(round(iF))
            let numberMin: Float = {
                switch observable.align {
                case .rect:
                    return Float(observable.numberLowest) - Float(observable.gridX) / 2 + Float(i * observable.gridY)
                case .hex:
                    return Float(observable.numberLowest) - Float(observable.gridX) / 2 + Float(i) * (Float(observable.gridY) - Float(observable.gridX) / 2)

                }
            }()
            
            let numberWidth = Float(observable.gridX * observable.nCols)
            
            let numberF = (x - widthKey) / (width - widthKey) * numberWidth + numberMin
            let number: Number = Int(observable.roundNumber(i, numberF))
            return .key(number, numberF)
        }
    }
    
    func update() {
        observable.sustainsCurrently = touchStates.values.contains(where: {
            if case .sustain = $0 {
                return true
            } else {
                return false
            }
        })
        
        observable.bendsCurrently = touchStates.values.contains(where: {
            if case .bend = $0 {
                return true
            } else {
                return false
            }
        })
    }
    
    func keyOn(_ touchHash: Int, _ number: Number, _ numberF: Float) {
        observable.sampler.play(touchHash, number, observable.bends ? numberF - Float(number) : 0)
    }
    
    func keyOff(_ touchHash: Int) {
        if(observable.sustains) {
            observable.sampler.sustain(touchHash)
        } else {
            observable.sampler.unplay(touchHash)
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.forEach { touch in
            let touchState = touchState(touch)
            if case let .key(number, numberF) = touchState {
                keyOn(touch.hash, number, numberF)
            }
            touchStates[touch.hash] = touchState
        }
        
        update()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touchStatesOld = touchStates
        
        touches.forEach { touch in
            touchStates[touch.hash] = touchState(touch)
        }
        
        update()
        
        touches.forEach { touch in
            let touchStateOld = touchStatesOld[touch.hash]!
            let touchState = touchStates[touch.hash]!
            
            switch touchStateOld {
            case let .key(numberOld, _):
                switch touchState {
                case let .key(number, numberF):
                    if(observable.bends) {
                        observable.sampler.bendTo(touch.hash, numberF)
                    } else if(numberOld != number) {
                        keyOff(touch.hash)
                        keyOn(touch.hash, number, numberF)
                    }
                case .sustain, .bend:
                    keyOff(touch.hash)
                }
            case .sustain, .bend:
                switch touchState {
                case let .key(number, numberF):
                    keyOn(touch.hash, number, numberF)
                case .sustain, .bend:
                    break
                }
            }
        }
    }
    
    func touchesEndedOrCancelled(_ touches: Set<UITouch>) {
        touches.forEach { touch in
            switch touchStates[touch.hash]! {
            case .sustain, .bend:
                touchStates.removeValue(forKey: touch.hash)
            case .key:
                break
            }
        }
        
        update()
        
        touches.forEach { touch in
            switch touchState(touch) {
            case .key:
                keyOff(touch.hash)
            case .sustain, .bend:
                break
            }
            
            touchStates.removeValue(forKey: touch.hash)
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEndedOrCancelled(touches)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEndedOrCancelled(touches)
    }
}
