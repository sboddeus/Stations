
import AVFoundation
import Foundation

final class RadioMetadataEnricher: NSObject, AVPlayerItemMetadataOutputPushDelegate {
    // This method takes a radio station and
    // returns a new radio station with the information
    // enriched with the collected metadata from a
    // streaming object
    func enrich(radio: Stream) -> Stream {
        Stream(
            id: radio.id,
            title: radio.title,
            description: trackTitle ?? radio.description,
            imageURL: radio.imageURL,
            url: radio.url
        )
    }

    // Sets the item from which we will pull metadata
    var metadataOutput: AVPlayerItemMetadataOutput?
    func set(enrichmentSource: AVPlayerItem) {
        let output = AVPlayerItemMetadataOutput()
        metadataOutput = output
        output.setDelegate(self, queue: DispatchQueue.main)
        enrichmentSource.add(output)
    }

    func removeEnrichmentObserver() {
        metadataOutput?.setDelegate(nil, queue: nil)
        metadataOutput = nil
    }

    // Delegate method used to extract enrichment data
    private var trackTitle: String?
    func metadataOutput(_: AVPlayerItemMetadataOutput, didOutputTimedMetadataGroups group: [AVTimedMetadataGroup], from _: AVPlayerItemTrack?) {
        Task {
            trackTitle = try? await group.first?.items.first(where: { item in item.commonKey == AVMetadataKey.commonKeyTitle })?.load(.stringValue)
        }
    }
}
