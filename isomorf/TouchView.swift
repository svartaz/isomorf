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
    case key(_ number: Int)
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
    
    func numberTouched(_ touch: UITouch) -> (Int, Float) {
        let location = touch.location(in: self)
        let x = Float(location.x)
        let y = Float(location.y)
        let width = Float(self.bounds.width)
        let height = Float(self.bounds.height)
        
        let numberF: Float = x / width * Float((observable.nKeys + 1) * 2 + 1) + Float(observable.numberLowest - 3)
        
        let isUpper: Bool = between(y, min: 0, max: height / 4) || between(y, min: height / 2, max: height / 4 * 3)
        let isEven: Bool = isUpper != observable.numberLowest.isMultiple(of: 2)
        
        let number: Number = Int(isEven ? roundEven(numberF) : roundOdd(numberF))
        return (number, numberF - Float(number))
    }
    
    func play(_ touch: UITouch) {
        let (number, diff) = numberTouched(touch)
        if(observable.bends) {
            observable.sampler.play(touch.hash, number, diff)
        } else {
            observable.sampler.play(touch.hash, number)
        }
        
        observable.played = observable.sampler.played.values.flatMap { notes in
            return notes.map { (note, _) in
                return observable.sampler.toNumber(note)
            }
        }
    }
    
    func unplay(_ touch: UITouch) {
        observable.sampler.unplay(touch.hash)
        observable.played = observable.sampler.played.values.flatMap { notes in
            return notes.map { (note, _) in
                return observable.sampler.toNumber(note)
            }
        }
    }
    
    func bend(_ touch: UITouch) {
        let (_, diff) = numberTouched(touch)
        observable.sampler.bend(touch.hash, diff)
    }
    
    func sustain(_ touch: UITouch) {
        observable.sampler.sustain(touch.hash)
    }
    
    func release(_ touch: UITouch) {
        if(observable.sustains) {
            sustain(touch)
        } else {
            unplay(touch)
        }
    }
    
    func update() {
        observable.sustainsCurrently = touchStates.values.contains(where: { $0 == .sustain})
        observable.bendsCurrently = touchStates.values.contains(where: { $0 == .bend})
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
            let (number, _) = numberTouched(touch)
            return .key(number)
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let touchState = touchState(touch)
            touchStates[touch.hash] = touchState
            switch touchState {
            case .key(_):
                play(touch)
            case .sustain, .bend:
                update()
            }
        }
    }
    
    func touchesCancelledOrEnded(_ touches: Set<UITouch>) {
        for touch in touches {
            let touchState = touchState(touch)
            
            switch touchState {
            case .key(_):
                release(touch)
            case .sustain, .bend:
                break
            }
            
            touchStates.removeValue(forKey: touch.hash)
            update()
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let touchState = touchState(touch)
            
            if let touchStateOld = touchStates[touch.hash] {
                switch touchStateOld {
                case .key(_):
                    if(touchStateOld == touchState) {
                        if(observable.bends) {
                            bend(touch)
                        }
                    } else {
                        release(touch)
                        play(touch)
                    }
                default:
                    play(touch)
                }
            } else {
                print("TouchView failed to move")
            }
            
            touchStates.updateValue(touchState, forKey: touch.hash)
        }
        
        update()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesCancelledOrEnded(touches)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesCancelledOrEnded(touches)
    }
}
