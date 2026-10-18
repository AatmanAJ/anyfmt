#!/usr/bin/env bash
# Filters xcodebuild output down to diagnostics from our sources + the result line.
grep -E "(/Sources/|/Tests/|/Packages/|/Spikes/)[^ ]*:[0-9]+:[0-9]+: (error|warning)|error:|\*\* (BUILD|TEST) (SUCCEEDED|FAILED)|Test Suite .*(passed|failed)|Executed [0-9]+ test|failed \(|XCTAssert" | grep -v "^    export" | awk '!seen[$0]++' | head -${1:-80}
