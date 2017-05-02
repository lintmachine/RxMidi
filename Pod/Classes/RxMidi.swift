//
//  MidiService.swift
//  loopdit
//
//  Created by cdann on 9/24/15.
//  Copyright © 2015 Lintmachine. All rights reserved.
//

import Foundation
import MIKMIDI

import RxSwift
import RxCocoa

public typealias RxMidiFilter = (Observable<MIKMIDICommand>) -> Observable<MIKMIDICommand>

public class RxMidi {
    
    public enum MidiChannel: UInt8 {
        case AllChannels = 0
        case Channel01
        case Channel02
        case Channel03
        case Channel04
        case Channel05
        case Channel06
        case Channel07
        case Channel08
        case Channel09
        case Channel10
        case Channel11
        case Channel12
        case Channel13
        case Channel14
        case Channel15
        case Channel16
    }

    public enum MidiValueRange: Float {
        case Min = 0.0
        case Max = 127.0
    }
    
    public static let sharedInstance = RxMidi()
    
    public var availableMidiSourceEndpoints = RxMidi._availableMidiSourceEndpoints()
    public var availableMidiDestinationEndpoints = RxMidi._availableMidiDestinationEndpoints()
    
    class func _availableMidiSourceEndpoints() -> Observable<[MIKMIDISourceEndpoint]> {
        
        return availableMidiEntities()
            .map {
                (availableEntities:[MIKMIDIEntity]) in
                
                var sources = [MIKMIDISourceEndpoint]()
                
                for entity in availableEntities {
                    for source in entity.sources {
                        sources.append(source)
                    }
                }
                
                return sources
            }
    }

    class func _availableMidiDestinationEndpoints() -> Observable<[MIKMIDIDestinationEndpoint]> {
        
        return availableMidiEntities()
            .map {
                (availableEntities:[MIKMIDIEntity]) in
                
                var destinations = [MIKMIDIDestinationEndpoint]()
                
                for entity in availableEntities {
                    for destination in entity.destinations {
                        destinations.append(destination)
                    }
                }
                
                return destinations
        }
    }
    
    class func availableMidiEntities() -> Observable<[MIKMIDIEntity]> {
        
        return Observable.of(
            NotificationCenter.default.rx.notification(NSNotification.Name.MIKMIDIDeviceWasAdded),
            NotificationCenter.default.rx.notification(NSNotification.Name.MIKMIDIDeviceWasRemoved)
        )
        .merge()
        .startWith(Notification(name: NSNotification.Name.MIKMIDIDeviceWasAdded, object: nil))
        .map {
            (notification:Notification) -> [MIKMIDIDevice] in
            
            let availableDevices = MIKMIDIDeviceManager.shared().availableDevices as [MIKMIDIDevice]
            return availableDevices
        }
        .map {
            (availableDevices:[MIKMIDIDevice]) in
            
            var entities = [MIKMIDIEntity]()
            
            for device in availableDevices {
                for entity in device.entities {
                    entities.append(entity)
                }
            }
            
            return entities
        }
    }
    
    public func midiCommandsForAllAvailableSources() -> Observable<MIKMIDICommand> {
        return RxMidi.midiCommandsForSourceEndpoints(
            endpoints: self.availableMidiSourceEndpoints.map {
                (sources:[MIKMIDISourceEndpoint]) -> Observable<MIKMIDISourceEndpoint> in
                return Observable.from(sources)
            }
            .switchLatest()
        )
    }
    
    public class func midiCommandsForSourceEndpoints(endpoints:Observable<MIKMIDISourceEndpoint>) -> Observable<MIKMIDICommand> {
        return endpoints.map {
            (source:MIKMIDISourceEndpoint) -> Observable<MIKMIDICommand> in
            return midiCommandsForSourceEndpoint(endpoint: source)
        }
        .merge()
    }
    
    public class func filterMidiCommands(commands:Observable<MIKMIDICommand>, forControllerNumber controllerNumber:UInt) -> Observable<MIKMIDICommand> {
        return commands
            .filter {
                (command:MIKMIDICommand) -> Bool in
                if let controlCommand = command as? MIKMIDIControlChangeCommand {
                    return controlCommand.controllerNumber == controllerNumber
                }
                
                return false
            }
    }
    
    public class func midiCommandsForSourceEndpoint(endpoint:MIKMIDISourceEndpoint) -> Observable<MIKMIDICommand> {
        return Observable.create {
            (observer:AnyObserver<MIKMIDICommand>) -> Disposable in
            
            var connectionToken:AnyObject?
            
            do {
                try connectionToken = MIKMIDIDeviceManager.shared().connectInput(endpoint) {
                    (source:MIKMIDISourceEndpoint, messages:[MIKMIDICommand]) -> Void in
                    for message in messages {
                        observer.on(.next(message))
                    }
                } as AnyObject
            }
            catch _ {
                observer.on(.error(NSError(domain: "com.lintmachine.rx_midi", code: -1, userInfo: [NSLocalizedDescriptionKey:"Failed to connect to midi source."])))
            }
            
            return Disposables.create() {
                if let token = connectionToken {
                    MIKMIDIDeviceManager.shared().disconnectConnection(forToken: token)
                    connectionToken = nil
                }
            }
        }
    }
    
    public class func sendMidiCommandsToDestination(commands:[MIKMIDICommand], destination:MIKMIDIDestinationEndpoint) -> Observable<Void> {
        return Observable.create {
            (observer:AnyObserver<Void>) -> Disposable in
            
            do {
                try MIKMIDIDeviceManager.shared().send(commands, to: destination)
            }
            catch _ {
                observer.on(.error(NSError(domain: "com.lintmachine.rx_midi", code: -1, userInfo: [NSLocalizedDescriptionKey:"Failed to send commands to midi destination."])))
            }

            observer.on(.completed)
            
            return Disposables.create()
        }
    }
    
    // MARK: - Message Stream Functions
    public class func filterControlChangeCommands(forControllerNumber controllerNumber:UInt) -> RxMidiFilter {
        return {
            (commands:Observable<MIKMIDICommand>) in
            
            return commands.filter {
                (command:MIKMIDICommand) -> Bool in
                
                if let controlCommand = command as? MIKMIDIControlChangeCommand {
                    return controlCommand.controllerNumber == controllerNumber
                }
                
                return false
            }
        }
    }
    
    public class func filterChannelVoiceCommands(forChannel channel:Observable<UInt8>) -> RxMidiFilter {
        return {
            (commands:Observable<MIKMIDICommand>) in
            
            return Observable.combineLatest(
                channel.distinctUntilChanged(),
                commands
            ) {
                (channel, command) -> (UInt8, MIKMIDICommand) in
                return (channel, command)
            }
            .filter {
                (channel: UInt8, command: MIKMIDICommand) -> Bool in
                
                if let voiceCommand = command as? MIKMIDIChannelVoiceCommand {
                    return voiceCommand.channel == channel
                }
                
                return false
            }
            .map {
                (channel:UInt8, command:MIKMIDICommand) -> MIKMIDICommand in
                return command
            }
        }
    }
    
    public class func monophonicVoiceMap(sourceChannel:Observable<UInt8>, destChannel:Observable<UInt8>) -> RxMidiFilter {
        return {
            voiceCommands in
            
            var noteOnCommand:MIKMIDINoteOnCommand? = nil
            
            return Observable.combineLatest(
                sourceChannel.distinctUntilChanged(),
                destChannel.distinctUntilChanged(),
                voiceCommands
                ) {
                    (sourceChannel:UInt8, destChannel:UInt8, voiceCommand:MIKMIDICommand) -> MIKMIDICommand in
                    
                    if let noteOn = noteOnCommand {
                        
                        // If our voice is currently on an we receive a matching note off command, remap the command to our voice channel and turn the voice off
                        if let noteOff = voiceCommand as? MIKMIDINoteOffCommand {
                            if noteOn.channel == noteOff.channel && noteOn.note == noteOff.note {
                                noteOnCommand = nil
                                return MIKMIDINoteOffCommand(note: noteOff.note, velocity: noteOff.velocity, channel: destChannel, timestamp: noteOff.timestamp)
                            }
                        }
                    }
                    else if let noteOn = voiceCommand as? MIKMIDINoteOnCommand {
                        
                        // If our voice is currently off an we receive a note on command, remap the command to our voice channel and turn the voice on
                        if noteOn.channel == sourceChannel {
                            noteOnCommand = noteOn
                            return MIKMIDINoteOnCommand(note: noteOn.note, velocity: noteOn.velocity, channel: destChannel, timestamp: noteOn.timestamp)
                        }
                    }
                    
                    return voiceCommand
            }
        }
    }
}

precedencegroup MultiplicationPrecedence {
    associativity: left
    higherThan: AdditionPrecedence
}
infix operator >>> : MultiplicationPrecedence

public func >>> (filter1: @escaping RxMidiFilter, filter2: @escaping RxMidiFilter) -> RxMidiFilter {
    return rx_composeFilters(filter1: filter1, filter2:filter2)
}

public func rx_composeFilters(filter1: @escaping RxMidiFilter, filter2: @escaping RxMidiFilter) -> RxMidiFilter {
    return {
        message in
        filter2(filter1(message))
    }
}
