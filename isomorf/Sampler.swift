//
//  Sampler.swift
//  isomorf
//
//  Created by sumi on 2023/01/27.
//

import AVFoundation
import AudioKit

typealias Channel = UInt8
typealias Number = Int

enum Play: Hashable {
    case touch(Int)
    case sustain(Date)
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .touch(let touchHash):
            hasher.combine(touchHash)
        case .sustain(let date):
            hasher.combine(date)
        }
    }
}

struct Sampler {
    private var engine = AudioEngine()
    private var sampler = MIDISampler()
    
    var url: URL? = nil
    
    // +- 2 octaves
    private let maxNumberBend: Int = 24
    
    private var instrument: Int = 0
    
    var played: [Play: (Number, Channel, Float)] = [:]
    
    init() {
        engine.output = sampler
        
        try! engine.start()
        sampler.enableMIDI()
    }
    
    func pitchBend(_ diff: Float) -> UInt16 {
        let maxPitchBend: Int = 16384

        let pitchBendF: Float = Float(maxPitchBend) / Float(maxNumberBend * 2) * diff + Float(maxPitchBend) / 2
        return UInt16.init(Int(pitchBendF))
    }
        
    mutating func play(_ touchHash: Int, _ number: Number, _ diff: Float) {
        played.forEach { (p: Play, v) in
            let (n, channel, _) = v
            if case .sustain(_) = p {
                if(n == number) {
                    sampler.stop(noteNumber: UInt8.init(n), channel: channel)
                    played.removeValue(forKey: p)
                }
            }
        }
        
        let channelsUsed: [Channel] = played.values.map { (_, c, _) in return c }
        if let channel: Channel = (0..<128).first(where: { !channelsUsed.contains($0)}) {
            sampler.setPitchbend(amount: pitchBend(diff), channel: channel)
            sampler.play(noteNumber: UInt8.init(number), velocity: 127, channel: MIDIChannel(channel))
            played[.touch(touchHash)] = (number, channel, diff)
            
        } else {
            print("Sampler failed to play note \(number)")
        }
    }
    
    mutating func unplay(_ touchHash: Int) {
        let p = Play.touch(touchHash)
        
        if let (number, channel, _) = played[p] {
            sampler.stop(noteNumber: UInt8.init(number), channel: channel)
            sampler.setPitchbend(amount: pitchBend(0), channel: channel)
            played.removeValue(forKey: p)
        } else {
            print("Sampler failed to unplay")
        }
    }
    
    mutating func bendTo(_ touchHash: Int, _ numberF: Float) {
        let p = Play.touch(touchHash)
        
        if let (number, channel, _) = played[p] {
            sampler.midiCC(100, value: 0, channel: channel)
            sampler.midiCC(101, value: 0, channel: channel)
            sampler.midiCC(6, value: UInt8.init(maxNumberBend), channel: channel)
            sampler.midiCC(100, value: 127, channel: channel)
            sampler.midiCC(101, value: 127, channel: channel)

            let diff = numberF - Float(number)
            sampler.setPitchbend(amount: pitchBend(diff), channel: channel)
            played[p] = (number, channel, diff)
        } else {
            print("Sampler failed to bend")
        }
    }
    
    mutating func unbend() {
        played.forEach { (p: Play, v) in
            let (number, channel, _) = v
            sampler.setPitchbend(amount: pitchBend(0), channel: channel)
            played[p] = (number, channel, 0)
        }
    }
    
    mutating func sustain(_ touchHash: Int) {
        let p = Play.touch(touchHash)
        played[.sustain(Date())] = played[p]
        played.removeValue(forKey: p)
    }
    
    mutating func unsustain() {
        played.forEach { (p: Play, v) in
            if case .sustain(_) = p {
                let (number, channel, _) = v
                sampler.stop(noteNumber: UInt8.init(number), channel: channel)
                played.removeValue(forKey: p)
            }
        }
    }
    
    mutating func loadInstrument() {
        loadInstrument(instrument)
    }
    
    mutating func loadInstrument(_ instrument: Int) {
        self.instrument = instrument
        
        if let url = url {
            _ = url.startAccessingSecurityScopedResource()
            try! sampler.loadMelodicSoundFont(url: url, preset: instrument)
            url.stopAccessingSecurityScopedResource()
            
            print("instrument \(instrument) loaded")
        } else {
            print("Sampler failed to load instrument")
        }
    }
}

let generalMidi = [
    "Acoustic Piano",
    "Bright Piano",
    "Electric Grand Piano",
    "Honky-tonk Piano",
    "Electric Piano",
    "Electric Piano 2",
    "Harpsichord",
    "Clavi",
    "Celesta",
    "Glockenspiel",
    "Music box",
    "Vibraphone",
    "Marimba",
    "Xylophone",
    "Tubular Bell",
    "Dulcimer",
    "Drawbar Organ",
    "Percussive Organ",
    "Rock Organ",
    "Church organ",
    "Reed organ",
    "Accordion",
    "Harmonica",
    "Tango Accordion",
    "Acoustic Guitar ",
    "Acoustic Guitar ",
    "Electric Guitar ",
    "Electric Guitar ",
    "Electric Guitar ",
    "Overdriven Guitar",
    "Distortion Guitar",
    "Guitar harmonics",
    "Acoustic Bass",
    "Electric Bass ",
    "Electric Bass ",
    "Fretless Bass",
    "Slap Bass 1",
    "Slap Bass 2",
    "Synth Bass 1",
    "Synth Bass 2",
    "Violin",
    "Viola",
    "Cello",
    "Double bass",
    "Tremolo Strings",
    "Pizzicato Strings",
    "Orchestral Harp",
    "Timpani",
    "String Ensemble 1",
    "String Ensemble 2",
    "Synth Strings 1",
    "Synth Strings 2",
    "Voice Aahs",
    "Voice Oohs",
    "Synth Voice",
    "Orchestra Hit",
    "Trumpet",
    "Trombone",
    "Tuba",
    "Muted Trumpet",
    "French horn",
    "Brass Section",
    "Synth Brass 1",
    "Synth Brass 2",
    "Soprano Sax",
    "Alto Sax",
    "Tenor Sax",
    "Baritone Sax",
    "Oboe",
    "English Horn",
    "Bassoon",
    "Clarinet",
    "Piccolo",
    "Flute",
    "Recorder",
    "Pan Flute",
    "Blown Bottle",
    "Shakuhachi",
    "Whistle",
    "Ocarina",
    "Lead 1 ",
    "Lead 2 ",
    "Lead 3 ",
    "Lead 4 ",
    "Lead 5 ",
    "Lead 6 ",
    "Lead 7 ",
    "Lead 8 ",
    "Pad 1 ",
    "Pad 2 ",
    "Pad 3 ",
    "Pad 4 ",
    "Pad 5 ",
    "Pad 6 ",
    "Pad 7 ",
    "Pad 8 ",
    "FX 1 ",
    "FX 2 ",
    "FX 3 ",
    "FX 4 ",
    "FX 5 ",
    "FX 6 ",
    "FX 7 ",
    "FX 8 ",
    "Sitar",
    "Banjo",
    "Shamisen",
    "Koto",
    "Kalimba",
    "Bagpipe",
    "Fiddle",
    "Shanai",
    "Tinkle Bell",
    "Agogo",
    "Steel Drums",
    "Woodblock",
    "Taiko Drum",
    "Melodic Tom",
    "Synth Drum",
    "Reverse Cymbal",
    "Guitar Fret Noise",
    "Breath Noise",
    "Seashore",
    "Bird Tweet",
    "Telephone Ring",
    "Helicopter",
    "Applause",
    "Gunshot"
]
