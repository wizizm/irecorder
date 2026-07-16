import Testing
@testable import IRecorderCore

@Test func rejectsCursorChromeLabels() {
    #expect(CursorChatTextPolicy.isCaptureCandidate("Fork chat") == false)
    #expect(CursorChatTextPolicy.isCaptureCandidate("Copy message") == false)
    #expect(CursorChatTextPolicy.isCaptureCandidate("Message sent 2026年7月16日 上午8:56") == false)
    #expect(CursorChatTextPolicy.isCaptureCandidate("Navigation actions") == false)
    #expect(CursorChatTextPolicy.isCaptureCandidate("a") == false)
}

@Test func rejectsSpacedVoiceOverStyleCJK() {
    #expect(CursorChatTextPolicy.isCaptureCandidate(" 厉害时  还是 有问题") == false)
    #expect(CursorChatTextPolicy.isCaptureCandidate("这样 改了 之后 其他 地方 输入") == false)
}

@Test func acceptsCoherentUserChatMessage() {
    #expect(CursorChatTextPolicy.isCaptureCandidate(
        "你这样改了之后其他地方的输入又异常了，能独立两条处理分支吗"
    ))
}


@Test func seenStringDiffReturnsOnlyNewTexts() {
    let diff = SeenStringDiff()
    #expect(diff.ingest(["a", "b"]).sorted() == ["a", "b"])
    #expect(diff.ingest(["a", "b", "c"]) == ["c"])
    #expect(diff.ingest(["a", "b", "c"]).isEmpty)
}

@Test func seenStringDiffBaselineSuppressesExisting() {
    let diff = SeenStringDiff()
    diff.replaceBaseline(["old1", "old2"])
    #expect(diff.ingest(["old1", "old2", "新消息"]).filter(CursorChatTextPolicy.isCaptureCandidate) == ["新消息"])
}
