# Fixture provenance

The JSON files come from real `xcrun xcresulttool get` output. A source project captured them on 2026-09-26 with Xcode 27.0, on an iPhone 17 Pro Max simulator with iOS 26.5. The capture ran one XCTest unit test with `-only-testing`.

Before the files came here, these changes were made, and no other change:

- The project, target, class, and method names became `App`, `AppTests`, `CalcTests`, and `testAdd`.
- The simulator id became all zeros.
- Each source path became `/path/to/app/Sources/Calc.swift` or `/path/to/app/Tests/CalcTests.swift`.
- The compiler error and the assertion message got values that fit `Calc`.

| Fixture | Command | Capture |
|---|---|---|
| `build-succeeded.json` | `get build-results` | The test failed. The build succeeded with no warnings. |
| `build-failed.json` | `get build-results` | A mutation changed a number to a string, so the build failed with 2 errors. |
| `tests-passed.json` | `get test-results tests` | The test passed on the clean tree. |
| `tests-failed.json` | `get test-results tests` | A mutation broke the code under the test, so the test failed. |
| `tests-none.json` | `get test-results tests` | The `-only-testing` name matched no test. `xcodebuild` exited 0. |

The fakes use the files:

- `fake-xcodebuild.sh` writes its arguments to `$FAKE_CALLS`. It finds a `MARK_` marker in the `Sources` folder of the current directory, and picks the outcome and the exit code from it. It keeps each `-only-testing` name that starts with `AppTests/` and does not hold `DoesNotExist`. It writes the outcome and the names into the result bundle.
- `fake-xcresulttool.py` reads them back. For each kept name, it copies the suite and test case nodes of the captured tree, and changes only `nodeIdentifierURL`, `nodeIdentifier`, `name`, `result`, and `children`. A class name gets two test cases, `testOne` and `testTwo`.

These outcomes have no capture. The fakes build them from the files:

- `SKIP` and `EXPECTED` give `Skipped` and `Expected Failure` as the result of each test case.
- `BUILD_ODD` is `build-failed.json` with no errors.
- `NOCOMPILE_EXIT0`, `EXIT0_FAILED`, and `EXIT65_PASSED` pair a captured file with the other exit code.
- `EXIT70` and `NOBUNDLE` write no bundle. `TOOL_FAIL` makes the fake tool exit 1, and `BAD_JSON` makes it print text that is not JSON.
