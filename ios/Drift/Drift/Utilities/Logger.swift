import Foundation
import os.log

enum LogLevel {
    case debug
    case info
    case warning
    case error
}

enum LogCategory: String {
    case app
    case auth
    case database
    case storage
    case worker
    case ui
}

protocol Logging {
    func log(_ level: LogLevel,
             _ message: String,
             category: LogCategory,
             error: Error?,
             file: String,
             function: String,
             line: Int)
}

extension Logging {
    func debug(_ message: String,
               category: LogCategory = .app,
               file: String = #fileID,
               function: String = #function,
               line: Int = #line) {
        log(.debug, message, category: category, error: nil, file: file, function: function, line: line)
    }

    func info(_ message: String,
              category: LogCategory = .app,
              file: String = #fileID,
              function: String = #function,
              line: Int = #line) {
        log(.info, message, category: category, error: nil, file: file, function: function, line: line)
    }

    func warning(_ message: String,
                 category: LogCategory = .app,
                 error err: Error? = nil,
                 file: String = #fileID,
                 function: String = #function,
                 line: Int = #line) {
        log(.warning, message, category: category, error: err, file: file, function: function, line: line)
    }

    func error(_ message: String,
               category: LogCategory = .app,
               error err: Error? = nil,
               file: String = #fileID,
               function: String = #function,
               line: Int = #line) {
        log(.error, message, category: category, error: err, file: file, function: function, line: line)
    }
}

final class DriftLogger: Logging {

    static let shared = DriftLogger()

    private let subsystem = "pro.aedev.drift"

    private func osLogger(for category: LogCategory) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }

    func log(_ level: LogLevel,
             _ message: String,
             category: LogCategory,
             error: Error?,
             file: String,
             function: String,
             line: Int) {

        let logger = osLogger(for: category)

        let meta = "[\(file):\(line) \(function)]"
        let full = error != nil
            ? "\(meta) \(message) | error=\(String(describing: error))"
            : "\(meta) \(message)"

        switch level {
        case .debug:
            logger.debug("\(full, privacy: .public)")
        case .info:
            logger.info("\(full, privacy: .public)")
        case .warning:
            logger.warning("\(full, privacy: .public)")
        case .error:
            logger.error("\(full, privacy: .public)")
        }
    }
}
