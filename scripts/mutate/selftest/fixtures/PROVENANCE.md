# Fixture provenance

The fixtures are result files in the shape of the runner contract. They are written by hand. They are not captures from a real runner, because the contract is the source of truth for the shape:

```
{"compiled": true|false, "tests": [{"id": "<id>", "result": "passed|failed|skipped"}]}
```

| Fixture | Outcome |
|---|---|
| `pass.json` | Each named test passed. |
| `killed.json` | Each named test failed. |
| `skipped.json` | Each named test was skipped. |
| `missing.json` | The code compiled, and no test ran. |
| `nocompile.json` | The code did not compile. |
| `invalid.json` | The file is not valid JSON. |
| `shape.json` | The file is valid JSON, but `compiled` is not `true` or `false`. |

The fake runner, `fake-runner.sh`, finds a `SELFTEST_` marker in the tree and gives `emit.py` the outcome. `emit.py` writes the result file with these changes to the fixture:

- If the fixture has an entry in `tests`, `emit.py` copies that entry for each test id that the fake runner knows. Each copy gets its test id in `id`.
- For the `SELFTEST_NOCOMPILE_STALE` marker, it takes `nocompile.json` and adds a `failed` entry for each test id. A case uses this file to prove that `compiled` set to false still gives `did-not-compile`.
- For the `SELFTEST_OTHER_FAILS` marker, it adds one `failed` entry for a test id that no mutation names.
- For `invalid.json`, it writes the file as it is.
- For the `SELFTEST_ERR_NOFILE` marker, the fake runner writes no result file and exits 1.

The fake runner knows a test id that starts with `suite/` and has exactly three parts. It does not know an id that holds `doesNotExist`. That is how a case asks for a test that does not run. If the fake runner knows none of the test ids, it writes `missing.json`. The exceptions are a compile failure and the error outcomes.

The `SELFTEST_RENAME_FOOBAR` marker makes the fake runner add `Bar` to each test id that it knows. So a case can ask for `suite/a_test/foo` while the result file has only `suite/a_test/fooBar`. The case proves that `results.py` compares test ids exactly and reports that `suite/a_test/foo` did not run.
