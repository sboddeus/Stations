
import Combine
import MediaPlayer
import SDWebImage

final class NowPlayingControlsController {
    private var cancellable: AnyCancellable?
    private var nowPlayingInfo = [String: Any]()

    static let imageURLIdKey = "ABCStationsNowPlayingImageURLKey"

    // MARK: - Bind to Publisher

    var lastKnownCurrentTime: CMTime?
    var lastKnownDuration: CMTime?
    func bind(toPlayer: AVAudioPlayer) {
        toPlayer.setupRemoteTransportControls()
        cancellable = toPlayer.playingState.sink(receiveValue: { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .loading, .initial:
                MPNowPlayingInfoCenter.default().playbackState = .stopped
            case .stopped: self.stopNowPlaying()
                MPNowPlayingInfoCenter.default().playbackState = .stopped
            case let .playing(item, duration, current, rate):
                self.displayNowPlaying(item: item, duration: duration, current: current, rate: rate)
                self.lastKnownDuration = duration
                self.lastKnownCurrentTime = current
                if MPNowPlayingInfoCenter.default().playbackState != .playing {
                    MPNowPlayingInfoCenter.default().playbackState = .playing
                }
            case let .paused(item):
                self.displayNowPlaying(item: item,
                                       duration: self.lastKnownDuration ?? .init(value: 0, timescale: .default),
                                       current: self.lastKnownCurrentTime ?? .init(value: 0, timescale: .default),
                                       rate: 0.0)
                MPNowPlayingInfoCenter.default().playbackState = .paused
            }
        })
    }

    // MARK: Now Playing Controls

    private func displayNowPlaying(item: MediaItem,
                                   duration: CMTime,
                                   current: CMTime,
                                   rate: Float)
    {
        // Create initial metadata info
        nowPlayingInfo[MPMediaItemPropertyTitle] = item.title
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = item.description?.truncatedForNowPlaying()

        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = current.seconds
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration.seconds
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = rate

        switch item {
        case .podcastEpisode:
            nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = false
        case .stream:
            nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = true
        }


        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

        // Set the image metadata
        if let currentURL = nowPlayingInfo[NowPlayingControlsController.imageURLIdKey] as? URL {
            if currentURL == item.imageURL {
                return
            }
        }
        SDWebImageDownloader.shared.downloadImage(with: item.imageURL) { [weak self] image, _, _, _ in
            guard let self = self else { return }
            if let image = image {
                self.nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                // Set the metadata
                MPNowPlayingInfoCenter.default().nowPlayingInfo = self.nowPlayingInfo
            }
        }
        nowPlayingInfo[NowPlayingControlsController.imageURLIdKey] = item.imageURL
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

        // Modify remote controls for item kind
        let commandCenter = MPRemoteCommandCenter.shared()
        switch item {
        case .podcastEpisode:
            commandCenter.skipBackwardCommand.isEnabled = true
            commandCenter.skipForwardCommand.isEnabled = true
        case .stream:
            commandCenter.skipBackwardCommand.isEnabled = false
            commandCenter.skipForwardCommand.isEnabled = false
        }
    }

    private func stopNowPlaying() {
        // Create initial metadata info
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0.0
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = 0.0
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0.0

        // Set the metadata
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}

extension String {
    func truncatedForNowPlaying() -> String? {
        if let str = split(whereSeparator: \.isNewline).first?.prefix(100) {
            return String(str)
        } else {
            return nil
        }
    }
}

// MARK: - Remote Transport Controls

extension AVAudioPlayer {
    func setupRemoteTransportControls() {
        // Get the shared MPRemoteCommandCenter
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.togglePlayPauseCommand.addTarget { [unowned self] _ in
            self.togglePlay()
            return .success
        }

        commandCenter.skipForwardCommand.preferredIntervals = [30]
        commandCenter.skipForwardCommand.addTarget { [unowned self] _ in
            self.seekForward()
            return .success
        }

        commandCenter.skipBackwardCommand.preferredIntervals = [30]
        commandCenter.skipBackwardCommand.addTarget { [unowned self] _ in
            self.seekBackward()
            return .success
        }

        commandCenter.seekForwardCommand.isEnabled = false
        commandCenter.seekBackwardCommand.isEnabled = false
    }
}
