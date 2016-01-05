//
//  ViewController.swift
//  RxMidi
//
//  Created by cdann on 09/28/2015.
//  Copyright (c) 2015 cdann. All rights reserved.
//

import UIKit
import RxMidi

import RxSwift
import RxCocoa

import MIKMIDI

class ViewController: UIViewController {

    let disposeBag = DisposeBag()
    
    let sourceChannel = ReplaySubject<UInt8>.create(bufferSize: 1)
    let voice0Channel = ReplaySubject<UInt8>.create(bufferSize: 1)
    let voice1Channel = ReplaySubject<UInt8>.create(bufferSize: 1)
    let voice2Channel = ReplaySubject<UInt8>.create(bufferSize: 1)
    
    override func viewDidLoad() {
        super.viewDidLoad()

        sourceChannel.onNext(0)
        voice0Channel.onNext(1)
        voice1Channel.onNext(2)
        voice2Channel.onNext(3)
        
        let polyphonicMaping = (
///            RxMidi.filterChannelVoiceCommands(forChannel:sourceChannel)
            RxMidi.monophonicVoiceMap(sourceChannel, destChannel:voice0Channel)
            >>> RxMidi.monophonicVoiceMap(sourceChannel, destChannel:voice1Channel)
            >>> RxMidi.monophonicVoiceMap(sourceChannel, destChannel:voice2Channel)
        )

        polyphonicMaping(RxMidi.sharedInstance.midiCommandsForAllAvailableSources())
        .subscribeNext {
            (command:MIKMIDICommand) -> Void in
            print("Command: \(command)")
        }
        .addDisposableTo(self.disposeBag)

        combineLatest(
            polyphonicMaping(RxMidi.sharedInstance.midiCommandsForAllAvailableSources()),
            RxMidi.sharedInstance.availableMidiDestinationEndpoints
        ) {
            (command:MIKMIDICommand, destinations:[MIKMIDIDestinationEndpoint]) -> Void in
            
            for destination in destinations {
                RxMidi.sendMidiCommandsToDestination([command], destination: destination)
                .subscribeCompleted {
                    () -> Void in
                }
                .addDisposableTo(self.disposeBag)
            }
        }
        .subscribeCompleted {
            () -> Void in
        }
        .addDisposableTo(self.disposeBag)
    }
}

