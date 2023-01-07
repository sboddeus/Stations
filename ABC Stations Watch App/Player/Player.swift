
import AVFoundation
import Combine
import Foundation
import MediaPlayer

// MARK: - Types

enum PlayingError: Error {
    case unknown
    case streamingFailed
    case none
}

enum PlayingState {
    case initial
    case stopped(PlayingError?)
    case playing(RadioStation, duration: CMTime, current: CMTime, rate: Float)
    case paused(RadioStation)
    case loading(RadioStation) // loading or buffering
}

let playerMessags = CurrentValueSubject<String, Never>("Initial")

/*
 The AVURLAssetQueue takes AVURLAssets and loads their meta-data on a background thread.
 It will then publish ready items on the readyItemSubject
 Due to some awkwardness, this class does expect the PlayerItem to be set on the AVURLAsset. If that
 property is not set the behaviour of this class is undefined. TODO: Fix it
 */
final class AVURLAssetQueue: NSObject {
    // MARK: - Interface

    // Adds an item to the queue and starts pre-fetching it
    func add(_ items: [AVURLAsset]) {
        playerMessags.send("ASSET QUEUE: Add")
        for item in items {
            queuedItems.append(item)
            if queuedItems.count == 1 {
                // Start loading items
                asyncLoadAsset(item)
            }
        }
    }

    // Nil will remove all items from the queue
    func remove(_ items: [AVURLAsset]?) {
        playerMessags.send("ASSET QUEUE: Remove")
        if let items = items {
            let cancelled = queuedItems.filter { item -> Bool in items.contains { $0.playerItem == item.playerItem } }
            cancelled.forEach { $0.cancelLoading()
            }
            queuedItems = queuedItems.filter { item -> Bool in !items.contains { $0.playerItem == item.playerItem } }
        } else { // remove all items
            queuedItems.forEach {
                $0.cancelLoading()
            }

            queuedItems = [AVURLAsset]()
        }
    }

    // Ready items signal
    var readyItemSubject = CurrentValueSubject<AVPlayerItem?, Never>(nil)

    // MARK: - Private Queues

    // Should only contain items that we are currently trying to load
    private(set) var queuedItems = [AVURLAsset]()

    // MARK: - Private Functions

    private func addReady(_ asset: AVPlayerItem) {
        playerMessags.send("ASSET QUEUE: Add ready")
        // First we double check it is still in queued items
        // there is a chance it was removed before this function was called!
        guard queuedItems.first?.playerItem == asset.asset.playerItem else { return }

        // Remove ready asset from queue
        queuedItems = Array(queuedItems.dropFirst())

        // Send the ready asset
        readyItemSubject.send(asset)

        // Load the next item
        if let next = queuedItems.first {
            asyncLoadAsset(next)
        }
    }

    private func remove(_ asset: AVURLAsset) {
        queuedItems = queuedItems.filter { $0.playerItem != asset.playerItem }
    }

    // Will load items in a background thread and add them
    // to the ready queue as they become ready.
    // It will load (and add) items in the order that it
    // is given them.
    private func asyncLoadAsset(_ newAsset: AVURLAsset) {
        playerMessags.send("ASSET QUEUE: Async load: \(newAsset.url)")
        /*
         Using AVAsset now runs the risk of blocking the current thread (the
         main UI thread) whilst I/O happens to populate the properties. It's
         prudent to defer our work until the properties we need have been loaded.
         */
        Task {
            do {
                guard try await newAsset.load(.isPlayable) else {
                    await MainActor.run {
                        playerMessags.send("ASSET QUEUE: Not playable")
                        remove(newAsset)
                    }
                    return
                }

                await MainActor.run {
                    playerMessags.send("ASSET QUEUE: Asset added to ready")
                    addReady(AVPlayerItem(asset: newAsset))
                }
            } catch {
                await MainActor.run {
                    playerMessags.send("ASSET QUEUE: Async load error: \(error.localizedDescription)")
                    remove(newAsset)
                }
            }
        }
    }
}

/*
 Architecture Overview

 The Player class takes in simple play commands and has several outputs for checking state. These
 include observales for playback state and queue state, as well as several direct accessors for
 current item type and current play rate.

 Internally the player queue is split amongst two objects. The AVURLAssetQueue and the
 AVPlayerQueue queue. The two queues combined form the total queue, with he AVPlayerQueue being the
 head.
 As AVURLAssets are loaded in the AVURLAssetQueue they are added to the AVPlayerQueue and removed from
 the AVURLAssetQueue.

 The Player class then listens to various feedback mechanisms on the AVQueuePlayer to monitor its state
 and appropriately respond to things like buffering, audio interrupts and streaming errors.

 */

final class AVAudioPlayer: NSObject {
    // MARK: - Shared

    static let shared = AVAudioPlayer(label: "global")

    // MARK: - Private Properties

    private let player: AVQueuePlayer
    private let itemQueue: AVURLAssetQueue

    private var forcePlayWhenReady: Bool = false

    // MARK: - Accessing Player State

    let playingState = CurrentValueSubject<PlayingState, Never>(.initial)
    let queueState = CurrentValueSubject<[RadioStation], Never>([])

    var currentItem: RadioStation? {
        if let item = player.currentItem?.asset.playerItem { return item }
        if let item = player.items().first?.asset.playerItem { return item }
        if let item = itemQueue.queuedItems.first?.playerItem { return item }
        return nil
    }

    var rate: Float { player.rate }

    // MARK: - Lifecycle

    // The label is not used
    // but you can not override an init() with a failable init?() so thanks ObjC
    init?(label _: String) {
        do {
            try AVAudioSession.sharedInstance()
                .setCategory(
                    AVAudioSession.Category.playback,
                    mode: .default,
                    policy: .longFormAudio,
                    options: []
                )
        } catch {
            playerMessags.send("Audio Player: Failed to start session")
            return nil
        }

        itemQueue = AVURLAssetQueue()

        player = AVQueuePlayer()

        super.init()
        addQueueObservers()
        addPlayerObservers()
    }

    // MARK: - Public Actions

    /// Starts playing the item passed immediately
    /// - Parameter item: A PlayerItem describing the resource to be played. A nil value is continues playing
    /// the currently played item if it was paused.
    func play(_ item: RadioStation? = nil) {
        playerMessags.send("Audio Player: Request to play item")
        // Check if there is a new item to play, or if we are just toggling
        guard let item = item else {
            playerMessags.send("Audio Player: No item play")
            player.play()
            return
        }

        // Make sure we are not already playing the item
        guard item.id != player.currentItem?.asset.playerItem?.id else {
            player.play()
            return
        }

        // Stop and remove anything currently playing
        stop()

        // Queue up new content
        let asset = AVURLAsset(playerItem: item)
        itemQueue.add([asset])

        // It is a radio station, force to play when ready
        forcePlayWhenReady = true
    }

    func pause() {
        player.pause()
        if let item = currentItem {
            playingState.send(.paused(item))
        } else {
            stop()
        }
    }

    func togglePlay() {
        if player.rate > 0 {
            pause()
        } else {
            play()
        }
    }

    func seekForward() {
        player.seek(to: player.currentTime() + .seekTime, toleranceBefore: .zero, toleranceAfter: .zero)
        // State change should be picked up by listener
    }

    func seekBackward() {
        player.seek(to: player.currentTime() - .seekTime, toleranceBefore: .zero, toleranceAfter: .zero)
        // State change should be picked up by listener
    }

    func seek(to: Float) {
        player.seek(to: CMTime(seconds: Double(to), preferredTimescale: .default), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    // MARK: Public Queue Items

    func addQueue(items: [RadioStation]) {
        // Filter out premium content if we are not premium
        // let items = items.filter { !($0.item.isPrem && !userIsPremium) }

        // add them to asset queue
        let assets: [AVURLAsset] = items.map { AVURLAsset(playerItem: $0) }
        itemQueue.add(assets)

        // Update queue state change
        queueState.send(allQueuedItems())
    }

    /// Remove specififed items from queue
    func removeFromQueue(items: [RadioStation]?) {

        guard let items = items else {
            stop()
            return
        }
        // Stop and remove current item if necessary
        if let current = player.currentItem {
            if items.contains(where: { $0 == current.asset.playerItem }) {
                player.pause()
                player.remove(current)
            }
        }

        // Remove all items from AVQueuePlayer
        let itemsToRemove = player.items().filter { item -> Bool in
            items.contains(where: { subItem -> Bool in item.asset.playerItem == subItem })
        }
        for item in itemsToRemove {
            player.remove(item)
        }

        let assets: [AVURLAsset] = items.map { AVURLAsset(playerItem: $0) }
        itemQueue.remove(assets)
        // Update queue state change
        queueState.send(allQueuedItems())
    }

    func move(item: Int, to: Int) {

        guard item != to else { return }

        var assets = queueState.value

        let element = assets.remove(at: item)
        assets.insert(element, at: to)

        // Reset queue states (not the most efficient implementation
        player.items().dropFirst().forEach { player.remove($0) }
        itemQueue.remove(nil)
        itemQueue.add(assets.map { AVURLAsset(playerItem: $0) })
        queueState.send(allQueuedItems())
    }

    let radioEnrichment = RadioMetadataEnricher()

    // MARK: - Listening and Observing

    private var queueCancellable: AnyCancellable?
    private func addQueueObservers() {
        queueCancellable = itemQueue.readyItemSubject.sink(receiveValue: { [weak self] asset in

            guard let self = self, let asset = asset else { return }

            playerMessags.send("Audio Player: Insert ready item")

            // Observe radio metadata if possible
            self.radioEnrichment.set(enrichmentSource: asset)

            // pop it into the queue
            self.player.insert(asset, after: nil)
        })
    }

    // Observing Tokens (Stupid AVFoundation)
    private var timeObserverToken: Any?

    private var audioQueueObserver: NSKeyValueObservation?
    private var audioItemStatusObserver: NSKeyValueObservation?
    private var audioQueueStallObserver: NSKeyValueObservation?

    private var notificationCentreErrorToken: NSObjectProtocol?
    private var notificationCentreInterruptionToken: NSObjectProtocol?

    private func addPlayerObservers() {
        // listening for current item change
        audioQueueObserver = observeAudioQueue()
        audioQueueStallObserver = observeAudioStall()

        timeObserverToken = timeObserver()

        notificationCentreInterruptionToken = interruptObserver()
        notificationCentreErrorToken = errorObserver()
    }

    // MARK: - Bind to sub manger

    private var userIsPremium: Bool { false }

    // MARK: - Private Helpers

    // Stops all media playback and removes all items from queue
    // should only call this if we enter an unknown state.
    // Most of the time a caller should call pause
    private func stop() {
        playerMessags.send("Audio Player: Stop, hammer time")

        player.pause()
        player.removeAllItems()
        itemQueue.remove(nil)
        queueState.send([])
        playingState.send(.stopped(nil))
    }

    private func allQueuedItems() -> [RadioStation] {
        player.items().dropFirst().compactMap(\.asset.playerItem) + itemQueue.queuedItems.compactMap(\.playerItem)
    }

    func clean() {
        stop()
    }

    // MARK: - Deinit Cleanup

    deinit {
        // Remove items from player
        player.removeAllItems()

        // Remove notification centre listeners
        if let token = notificationCentreInterruptionToken {
            notificationCentreInterruptionToken = nil
            NotificationCenter.default.removeObserver(token)
        }
        if let token = notificationCentreErrorToken {
            notificationCentreErrorToken = nil
            NotificationCenter.default.removeObserver(token)
        }

        // Stop radio enrichment
        radioEnrichment.removeEnrichmentObserver()

        // Remove KVO listeners
        audioQueueObserver?.invalidate()
        audioQueueObserver = nil
        audioQueueStallObserver?.invalidate()
        audioQueueStallObserver = nil
        audioItemStatusObserver?.invalidate()
        audioItemStatusObserver = nil

        // Remove time observer
        if let timeObserverToken = timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }
}

extension AVAudioPlayer {
    private func observeItemStatus(_ item: AVPlayerItem) {
        audioItemStatusObserver?.invalidate()
        audioItemStatusObserver = nil
        audioItemStatusObserver = item.observe(\.status, options: [.new, .old], changeHandler: { [weak self] item, _ in
            switch item.status {
            case .readyToPlay:
                if self?.forcePlayWhenReady ?? false {
                    Task { [player = self?.player] in
                        playerMessags.send("Audio Player: Preroll ya k-hole")
                        await player?.preroll(atRate: 1.0)
                        playerMessags.send("Audio Player: Play!!!!!")
                        player?.play()
                    }
                    self?.forcePlayWhenReady = false
                }
            case .failed, .unknown:
                playerMessags.send("Audio Player: Failed whale")
                // For debug builds stop here and investigate
                // DEBUGGING TIP: It seems like some resources are links to html players and
                // not the actual audio resource
                assertionFailure(item.error!.localizedDescription)
                // Recover by removing pausing and removing all items from queue
                self?.stop()
            @unknown default:
                playerMessags.send("Audio Player: Extra failed")
                // If we get here we sould probably handle the new case explicitly
                assertionFailure()
                // Recover by removing pausing and removing all items from queue
                self?.stop()
            }
        })
    }

    private func errorObserver() -> NSObjectProtocol {
        // Disabled because it is returned
        // swiftlint:disable:next discarded_notification_center_observer
        NotificationCenter.default.addObserver(forName: .AVPlayerItemNewErrorLogEntry, object: nil, queue: .main, using: { [weak self] thing in
            playerMessags.send("Audio Player: Item error: \(thing.description)")
            self?.stop()
        })
    }

    private func interruptObserver() -> NSObjectProtocol {
        // Disabled because it is returned
        // swiftlint:disable:next discarded_notification_center_observer
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main, using: { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue)
            else {
                return
            }

            // Switch over the interruption type.
            playerMessags.send("Audio Player: Interruption type: \(type)")
            switch type {
            case .ended:
                guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    self?.play()
                }
            default: self?.pause()
            }
        })
    }

    private func timeObserver() -> Any {
        // Notify every half second
        let time = CMTime(seconds: 0.5, preferredTimescale: .default)

        return player.addPeriodicTimeObserver(forInterval: time, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            guard let avItem = self.player.currentItem else {
                return
            }
            guard var item = avItem.asset.playerItem else {
                return
            }

            // If the item is a radio station we will
            // enrich it with approariate metadata
            item = self.radioEnrichment.enrich(radio: item)

            switch self.player.timeControlStatus {
            case .paused: break // Picked up elsewhere
            case .playing:
                // Then update state for currently playing status
                self.playingState.send(.playing(item,
                                                duration: self.player.currentItem?.duration ?? .kinderlingZero,
                                                current: self.player.currentTime(),
                                                rate: self.player.rate))
            case .waitingToPlayAtSpecifiedRate:
                self.playingState.send(.loading(item)) // Picked up elsewhere
            @unknown default:
                // If we get here we should probably handle the new case explicitly
                assertionFailure()
            }
        }
    }

    private func observeAudioStall() -> NSKeyValueObservation {
        player.observe(\.timeControlStatus, options: [.new, .old], changeHandler: { [weak self] player, _ in
            guard let self = self else { return }
            switch player.timeControlStatus {
            case .paused: break // Picked up elsewhere
            case .playing: break // Picked up elsewhere
            case .waitingToPlayAtSpecifiedRate:
                if let item = player.currentItem?.asset.playerItem {
                    self.playingState.send(.loading(item))
                } else if let item = self.itemQueue.queuedItems.first?.playerItem {
                    self.playingState.send(.loading(item))
                } else {
                    // If there is no item and we reached here
                    // it probably means the end
                    self.stop()
                }
            default:
                print("no changes")
            }
        })
    }

    private func observeAudioQueue() -> NSKeyValueObservation {
        player.observe(\.currentItem, options: [.new]) { [weak self] _, item in
            guard let self = self else { return }
            if let item = item.newValue, let safeItem = item {
                self.observeItemStatus(safeItem)
            }
            playerMessags.send("Audio Player: media item changed...")
            print("media item changed...")
            // Update state, if no items and no queued items then stopped,
            // else if not items but items queued then loading
            // else still playing and do nothing
            if self.player.items().count == 0, self.player.currentItem == nil {
                if self.itemQueue.queuedItems.count > 0 {
                    if let loadingItem = self.itemQueue.queuedItems.first?.playerItem {
                        self.playingState.send(.loading(loadingItem))
                    } else {
                        assertionFailure("Should always have a loading item")
                        self.stop()
                    }
                } else { // We have no more media so we will stop
                    self.stop()
                }
            }

            // Queues have likely changed so send a queue update
            self.queueState.send(self.allQueuedItems())
        }
    }
}

// MARK: - Helpers

extension Double {
    static var seekTime = 15.0
}

extension CMTime {
    static var kinderlingZero: CMTime {
        CMTime(seconds: 0.0, preferredTimescale: .default)
    }

    static var seekTime: CMTime {
        CMTime(seconds: .seekTime, preferredTimescale: .default)
    }

    var timeInterval: TimeInterval { Double(value) / Double(timescale) }
}

extension CMTimeScale {
    /// A single second time scale, to make time operations simpler.
    static var `default`: CMTimeScale {
        CMTimeScale(NSEC_PER_SEC)
    }
}

// MARK: - Objective C

import ObjectiveC

private var associatedObjectHandle: UInt8 = 0

extension AVAsset {
    var playerItem: RadioStation? {
        get {
            objc_getAssociatedObject(self, &associatedObjectHandle) as? RadioStation
        }
        set {
            objc_setAssociatedObject(self, &associatedObjectHandle, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

extension AVURLAsset {
    convenience init(playerItem: RadioStation) {
        self.init(url: playerItem.url)
        self.playerItem = playerItem
    }
}
