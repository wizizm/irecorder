import Testing
import IRecorderCore

@Suite("DownloadProgressFormat")
struct DownloadProgressFormatTests {
    @Test func fractionWhenTotalKnown() {
        #expect(DownloadProgressFormat.fraction(written: 50, total: 200) == 0.25)
        #expect(DownloadProgressFormat.fraction(written: 0, total: 100) == 0)
        #expect(DownloadProgressFormat.fraction(written: 100, total: 100) == 1)
    }

    @Test func fractionNilWhenTotalUnknownOrZero() {
        #expect(DownloadProgressFormat.fraction(written: 50, total: nil) == nil)
        #expect(DownloadProgressFormat.fraction(written: 50, total: 0) == nil)
        #expect(DownloadProgressFormat.fraction(written: 50, total: -1) == nil)
    }

    @Test func chineseMessageWithTotal() {
        let text = DownloadProgressFormat.message(
            prefix: "正在下载更新…",
            written: 1_572_864,
            total: 3_145_728,
            language: .chinese
        )
        #expect(text.contains("正在下载更新…"))
        #expect(text.contains("50%"))
        #expect(text.contains("/"))
    }

    @Test func messageWithoutTotalOmitsPercent() {
        let text = DownloadProgressFormat.message(
            prefix: "Downloading Update…",
            written: 1_048_576,
            total: nil,
            language: .english
        )
        #expect(text.hasPrefix("Downloading Update…"))
        #expect(!text.contains("%"))
    }
}
