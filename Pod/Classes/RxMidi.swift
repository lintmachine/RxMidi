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

public class RxMidi {
    
    public enum MidiChannel: Int {
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
        
        return sequenceOf(
            NSNotificationCenter.defaultCenter().rx_notification(MIKMIDIDeviceWasAddedNotification),
            NSNotificationCenter.defaultCenter().rx_notification(MIKMIDIDeviceWasRemovedNotification)
            )
            .merge()
            .startWith(NSNotification(name: MIKMIDIDeviceWasAddedNotification, object: nil))
            .map {
                (notification:NSNotification) -> [MIKMIDIDevice] in
                
                let availableDevices = MIKMIDIDeviceManager.sharedDeviceManager().availableDevices as [MIKMIDIDevice]
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
            self.availableMidiSourceEndpoints.map {
                (sources:[MIKMIDISourceEndpoint]) -> Observable<MIKMIDISourceEndpoint> in
                return sources.asObservable()
            }
            .switchLatest()
        )
    }
    
    public class func midiCommandsForSourceEndpoints(endpoints:Observable<MIKMIDISourceEndpoint>) -> Observable<MIKMIDICommand> {
        return endpoints.map {
                (source:MIKMIDISourceEndpoint) -> Observable<MIKMIDICommand> in
                return midiCommandsForSourceEndpoint(source)
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
        return create {
            (observer:AnyObserver<MIKMIDICommand>) -> Disposable in
            
            var connectionToken:AnyObject?
            
            do {
                try connectionToken = MIKMIDIDeviceManager.sharedDeviceManager().connectInput(endpoint) {
                    (source:MIKMIDISourceEndpoint, messages:[MIKMIDICommand]) -> Void in
                    for message in messages {
                        observer.on(.Next(message))
                    }
                }
            }
            catch _ {
                observer.on(.Error(NSError(domain: "com.lintmachine.rx_midi", code: -1, userInfo: [NSLocalizedDescriptionKey:"Failed to connect to midi source."])))
            }
            
            return AnonymousDisposable {
                if let token = connectionToken {
                    MIKMIDIDeviceManager.sharedDeviceManager().disconnectConnectionForToken(token)
                    connectionToken = nil
                }
            }
        }
    }
    
    public class func sendMidiCommandsToDestination(commands:[MIKMIDICommand], destination:MIKMIDIDestinationEndpoint) -> Observable<Void> {
        return create {
            (observer:AnyObserver<Void>) -> Disposable in
            
            do {
                try MIKMIDIDeviceManager.sharedDeviceManager().sendCommands(commands, toEndpoint: destination)
            }
            catch _ {
                observer.on(.Error(NSError(domain: "com.lintmachine.rx_midi", code: -1, userInfo: [NSLocalizedDescriptionKey:"Failed to send commands to midi destination."])))
            }

            observer.on(.Completed)
            
            return NopDisposable.instance
        }
    }
}