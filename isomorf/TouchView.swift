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
    case key(_ number: Number, _ diff: Float)
}

class TouchView: UIView, UIGestureRecognizerDelegate {
    let maxPitchBend: UInt16 = 16384
    
    var touchStates: [Int:TouchState] = [:]
    @ObservedObject var observable: Observable
    
    init(observable: Observable) {
        self.observable = observable
        
        super.init(frame: .zero)
        self.isMultipleTouchEnabled = true
        //self.isUserInteractionEnabled = false
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    func touchState(_ touch: UITouch) -> TouchState {
        let width = Float(self.bounds.width)
        let height = Float(self.bounds.height)
        let widthKey = width / ((Float(observable.nKeys) + 1) * 2 + 1) * 2
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
            let isUpper: Bool = between(y, min: 0, max: height / 4) || between(y, min: height / 2, max: height / 4 * 3)
            let isEven: Bool = isUpper != observable.numberLowest.isMultiple(of: 2)
            
            let numberF: Float = x / width * Float((observable.nKeys + 1) * 2 + 1) + Float(observable.numberLowest - 3)
            let number: Number = Int(isEven ? roundEven(numberF) : roundOdd(numberF))
            return .key(number, numberF - Float(number))
        }
    }
    
    func update() {
        observable.sustainsCurrently = touchStates.values.contains(where: {
            switch $0 {
            case .sustain:
                return true
            default:
                return false
            }
        })
        
        observable.bendsCurrently = touchStates.values.contains(where: {
            switch $0 {
            case .bend:
                return true
            default:
                return false
            }
        })
    }
    
    func begin(_ touch: UITouch, _ touchState: TouchState) {
        if case let .key(number, diff) = touchState {
            self.play(touch.hash, number, diff)
        }
        
        touchStates[touch.hash] = touchState
    }
    
    func end(_ touch: UITouch, _ touchState: TouchState) {
        if case let .key(number, _) = touchState {
            if(observable.sustains) {
                observable.sampler.sustain(touch.hash)
            } else {
                _ = observable.sampler.unplay(touch.hash)
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.forEach { touch in
            let touchState = touchState(touch)
            if case let .key(number, diff) = touchState {
                play(touch.hash, number, diff)
            }
            
            touchStates[touch.hash] = touchState
        }
        
        update()
    }
    
    func touchesEndedOrCancelled(_ touches: Set<UITouch>) {
        touches.forEach { touch in
            let touchState = touchState(touch)
            
            switch touchState {
            case .key(_, _):
                break
            default:
                touchStates.removeValue(forKey: touch.hash)
            }
        }
        
        update()
        
        touches.forEach { touch in
            let touchState = touchState(touch)
            
            switch touchState {
            case let .key(number, _):
                release(touch.hash, number)
                touchStates.removeValue(forKey: touch.hash)
            default:
                break
            }
        }
    }
    
    func play(_ touchHash: Int, _ number: Number, _ diff: Float) {
        observable.sampler.play(touchHash, Sampler.toNote(number), observable.bends ? diff : 0)
    }
    
    func release(_ touchHash: Int, _ number: Number) {
        if(observable.sustains) {
            observable.sampler.sustain(touchHash)
        } else {
            observable.sampler.unplay(touchHash)
        }
    }
    
    func bend(_ number: Number, _ diff: Float) {
        if(observable.bends) {
            observable.sampler.bend(Sampler.toNote(number), diff)
        }
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
                case let .key(number, diff):
                    if(numberOld == number) {
                        bend(number, diff)
                    } else {
                        release(touch.hash, numberOld)
                        play(touch.hash, number, diff)
                    }
                default:
                    release(touch.hash, numberOld)
                }
            default:
                switch touchState {
                case let .key(number, diff):
                    play(touch.hash, number, diff)
                default:
                    break
                }
            }
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        //touchesEndedOrCancelled(touches)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEndedOrCancelled(touches)
    }
}
