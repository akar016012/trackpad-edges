import Foundation

/// The project's pages on GitHub, which the menu bar item and the welcome tour open.
enum ProjectLinks {
    static let repository = URL(string: "https://github.com/akar016012/trackpad-edges")!
    static let releases = repository.appendingPathComponent("releases")
    /// The empty bug report form. The diagnostics report never travels in this link, because a
    /// link can end up in a browser's history and in a server's log.
    static let newBugReport = URL(
        string: repository.absoluteString + "/issues/new?template=bug_report.yml")!

    /// The notes for the running version, because those describe what you have. A build with no
    /// version falls back to the list of every release.
    static func releaseNotes(for version: String?) -> URL {
        guard let version, !version.isEmpty else { return releases }
        return releases.appendingPathComponent("tag").appendingPathComponent("v\(version)")
    }
}
