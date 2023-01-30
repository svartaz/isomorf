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
    
    private let maxPitchBend: Int = 16384
    private let maxNoteBend: Int = 4
    
    private var instrument: Int = 0
    
    var played: [Number: (Play, Channel, Float)] = [:]
    
    init() {
        engine.output = sampler
        try! engine.start()
        sampler.enableMIDI()
    }
    
    func pitchBend(_ diff: Float) -> UInt16 {
        let pitchBendF: Float = diff * (Float(maxPitchBend) / Float(maxNoteBend)) + Float(maxPitchBend) / 2
        return UInt16.init(Int(pitchBendF))
    }
    
    var channelsUsed: [Channel] {
        played.values.map { (_, channelOld, _) in
            return channelOld
        }
    }
    
    mutating func play(_ touchHash: Int, _ number: Number, _ diff: Float) {
        if let (_, channel, diff) = played[number] {
            sampler.play(noteNumber: UInt8.init(number), velocity: 127, channel: MIDIChannel(channel))
            played[number] = (.touch(touchHash), channel, diff)
        } else if let channel: Channel = (0..<128).first(where: { !channelsUsed.contains($0)}) {
            sampler.play(noteNumber: UInt8.init(number), velocity: 127, channel: MIDIChannel(channel))
            played[number] = (.touch(touchHash), channel, diff)
            
        } else {
            print("Sampler failed to play note \(number)")
        }
    }
    
    mutating func unplay(_ touchHash: Int) {
        played.forEach { (number: Number, value) in
            if case let (.touch(th), channel, _) = value {
                if(th == touchHash) {
                    sampler.stop(noteNumber: UInt8.init(number), channel: channel)
                    played.removeValue(forKey: number)
                }
            }
        }
    }
    
    mutating func bend(_ number: Number, _ diff: Float) {
        played.forEach { (n: Number, value) in
            let (p, channel, _) = value
            if(n == number) {
                sampler.setPitchbend(amount: pitchBend(diff), channel: channel)
                played[n] = (p, channel, diff)
            }
        }
    }
    
    mutating func unbend() {
        played.forEach { (n: Number, value) in
            let (p, channel, _) = value
            sampler.setPitchbend(amount: pitchBend(0), channel: channel)
            played[n] = (p, channel, 0)
        }
    }
    
    mutating func sustain(_ touchHash: Int) {
        played.forEach { (note: Number, value) in
            if case let (.touch(_), channel, diff) = value {
                played[note] = (.sustain(Date()), channel, diff)
            }
        }
    }
    
    mutating func unsustain() {
        played.forEach { (number: Number, value) in
            if case let (.sustain(_), channel, _) = value {
                sampler.stop(noteNumber: UInt8.init(number), channel: channel)
                played.removeValue(forKey: number)
            }
        }
    }
    
    var isPercussive: Bool {
        return 112 <= instrument && instrument < 120
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
