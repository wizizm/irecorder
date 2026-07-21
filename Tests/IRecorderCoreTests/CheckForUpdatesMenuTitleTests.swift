import Testing
import IRecorderCore

@Suite("CheckForUpdatesMenuTitle")
struct CheckForUpdatesMenuTitleTests {
    @Test func chineseIncludesAppNameAndVersion() {
        #expect(
            CheckForUpdatesMenuTitle.format(version: "1.1.0", language: .chinese)
                == "检查更新（iRecorder v1.1.0）"
        )
    }

    @Test func englishIncludesAppNameAndVersion() {
        #expect(
            CheckForUpdatesMenuTitle.format(version: "1.1.0", language: .english)
                == "Check for Updates (iRecorder v1.1.0)"
        )
    }
}
