import Foundation

/// Background poller that stays alive even when menu-bar apps would App-Nap.
final class Poller {
    private var timer: DispatchSourceTimer?
    private let interval: TimeInterval
    private let queue: DispatchQueue
    private let handler: () -> Void

    init(interval: TimeInterval, queue: DispatchQueue = .main, handler: @escaping () -> Void) {
        self.interval = interval
        self.queue = queue
        self.handler = handler
    }

    func start() {
        stop()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(50))
        timer.setEventHandler { [weak self] in
            self?.handler()
        }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }
}
