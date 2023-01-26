//
//  Sampler.swift
//  isomorf
//
//  Created by sumi on 2023/01/27.
//

import AVFoundation

typealias Channel = UInt8
typealias Note = UInt8
typealias Number = Int

class Sampler {
    private var engine = AVAudioEngine()
    private var unitSampler = AVAudioUnitSampler()
    
    private let maxPitchBend: Int = 16384
    private let maxNoteBend: Int = 4
    
    var played: [Int: [(Note, Channel)]] = [:]
    var sustained: Set<Int> = []
    
    private var channelsUsed: [Channel] {
        return played.values.flatMap { value in
            value.map {
                let (_, channel) = $0
                return channel
            }
        }
    }
    
    func toNote(_ number: Number) -> Note {
        return UInt8.init(number - 2)
    }
    
    func toNumber(_ note: Note) -> Number {
        return Int(note + 2)
    }
    
    init() {
        engine.attach(unitSampler)
        engine.connect(unitSampler, to: engine.mainMixerNode, format: nil)
        
        loadInstrument(0)
        
        do {
            try engine.start()
        } catch {
            print("Sampler falied to start engin")
        }
    }
    
    func pitchBend(_ diff: Float) -> UInt16 {
        let pitchBendF: Float = diff * (Float(maxPitchBend) / Float(maxNoteBend)) + Float(maxPitchBend) / 2
        return UInt16.init(Int(pitchBendF))
    }
    
    func play(_ id: Int, _ number: Int) {
        for channel: Channel in 0..<128 {
            if(!channelsUsed.contains(channel)) {
                let pitchBend: UInt16 = .init(maxPitchBend / 2)
                unitSampler.sendPitchBend(pitchBend, onChannel: channel)
                
                let note: UInt8 = toNote(number)
                unitSampler.startNote(note, withVelocity: 127, onChannel: channel)
                if let _ = played[id] {
                    played[id]?.append((note, channel))
                } else {
                    played[id] = [(note, channel)]
                }
                return
            }
        }
        print("Sampler failed to play")
    }
    
    func play(_ id: Int, _ number: Int, _ diff: Float) {
        for channel: Channel in 0..<128 {
            if(!channelsUsed.contains(channel)) {
                let note = toNote(number)
                unitSampler.sendPitchBend(pitchBend(diff), onChannel: channel)
                unitSampler.startNote(note, withVelocity: 127, onChannel: channel)
                
                if let _ = played[id] {
                    played[id]?.append((note, channel))
                } else {
                    played[id] = [(note, channel)]
                }
                return
            }
        }
        print("Sampler failed to play")
    }
    
    func unplay(_ id: Int) {
        if let notes = played[id] {
            notes.forEach { (note, channel) in
                unitSampler.stopNote(note, onChannel: channel)
            }
            played.removeValue(forKey: id)
        } else {
            print("Sampler failed to unplay")
        }
    }
    
    func bend(_ id: Int, _ diff: Float) {
        if let notes = played[id] {
            // FIXME: all the channels are bent
            notes.forEach { (note, channel) in
                unitSampler.sendPitchBend(pitchBend(diff), onChannel: channel)
            }
        } else {
            print("Sampler failed to bend")
        }
    }
    
    func unbend() {
        for channel in channelsUsed {
            unitSampler.sendPitchBend(UInt16.init(maxPitchBend / 2), onChannel: channel)
        }
    }
    
    func sustain(_ id: Int) {
        sustained.insert(id)
    }
    
    func unsustain() {
        sustained.forEach { id in
            unplay(id)
        }
    }
    
    func loadInstrument(_ instrument: UInt8) {
        if let url = Bundle.main.url(forResource: "SGM-V2.01", withExtension: "sf2"),
           let _ = try? unitSampler.loadSoundBankInstrument(
            at: url, program: instrument,
            bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
            bankLSB: UInt8(kAUSampler_DefaultBankLSB))
        {
            print("instrument \(instrument) loaded")
        } else {
            print("Sampler failed to load instrument")
        }
    }
}
