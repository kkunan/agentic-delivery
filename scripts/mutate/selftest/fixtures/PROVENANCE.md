# Fixture provenance

captured: xcresulttool get test-results summary / tests / build-results, 2026-09-26, develop 4fdb638,
device AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA, by the P-01 controller. The probe script and logs are in the P-01 ledger folder,
`probe-captured/`.

| Fixture | Capture |
|---|---|
| `pass.*.json` | `-only-testing:AppTests/ChatScrollGeometryTests/testTheThresholdIs88` on the clean tree |
| `killed.*.json` | The same test, with `nearBottomThreshold` changed from `88` to `89` |
| `nocompile.*.json` | The same test, with `nearBottomThreshold` changed from `88` to `"88"` |
| `missing.*.json` | `-only-testing:AppTests/ChatScrollGeometryTests/testDoesNotExist` on the clean tree |

The files are verbatim. `emit.py` prints them as they are, with three exceptions:

- The `tests` tree for a compile failure is `nocompile.tests.json` and for a run of no test is
  `missing.tests.json`, both verbatim. For every other outcome, `emit.py` takes the captured tree,
  `killed.tests.json` for a kill and `pass.tests.json` otherwise, copies its `Test Suite` and
  `Test Case` nodes once per test name, and substitutes only `nodeIdentifierURL`, `nodeIdentifier`,
  `name` and `result`. `result` is `Passed`, `Failed` for a kill, or `Skipped`.
- For the `no-field` outcome it removes `totalTestCount` and `passedTests` from `pass.test-results.json`.
- `skipped.test-results.json` has no capture. spec: decision 14, "a run where every test was skipped,
  which has `passedTests` 0". It is `pass.test-results.json` with `passedTests` 0, `skippedTests` 1
  and `result` `Skipped`, at the top level and for the device.

A name whose first component is not `AppTests` or `AppUITests`, or that has fewer than two
or more than three components, gets no node. spec: decision 10. That is the fake's stand-in for a
name that runs nothing; the real behaviour for such a name is not measured.

The fake `xcodebuild` applies the same rule. When no name passed to it survives the rule, and the
build does not fail, it runs no test: it exits 0 and its bundle gives the `missing` fixtures, as the
real tool did for `testDoesNotExist` in the probe.

spec: "Inputs the author believes the runner mishandles", "Names `.../testFoo` and a node for
`.../testFooBar`: a prefix or suffix match reports that `testFoo` ran". `SELFTEST_RENAME_FOOBAR` in
the tree makes the fake append `Bar` to every kept name before it is written to `selftest-names`, so
a case can ask for `testFoo` while only a `testFooBar` node exists, and prove that the equality check
in `results.py` correctly reports it as not run.
