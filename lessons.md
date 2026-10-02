# Lessons

Each section tells the incident behind one rule of the skill `run-rules`. The incidents come from real runs. They carry no names.

## silent-command

An agent searched for a pattern and got no hits. It reported that the thing did not exist. The command had no way to produce a hit. One search used a regular expression feature that the tool does not support. One search read a log that holds only commit messages. One count came from an incremental build that does not repeat old warnings. One process search matched the shell of the agent itself. Two corrections went to other sessions and the agent then withdrew them.

Rule: Before you assert a negative, name what a positive result looks like in the output that you have.

## pattern-blind-spots

A boundary lint passed all of its original tests. Review then found six valid inputs that slipped through, over three rounds. In another run, three searches written into a plan each matched only the break that their author had in mind. Review found seven misses over four rounds. Rounds that started with a named counterexample closed the first time.

Rule: For pattern-matching code, write at least one case that you think the pattern misses, and put it in the brief.

## committed-diff-copy

A team wrote a check for one additive change. Five rounds of line rules each closed one hole and opened the next. The fourth round showed that no line rule can tell a harmless partial removal from a harmful one. The team then committed exact copies of the edits beside the check. That ended the rounds.

Rule: A check that proves the edits of one ticket is an exact copy of those edits. If the check must gate later tickets, write a general rule.

## sweep-by-subject

A spec change slipped through a sweep five times. The sweep searched for the old wording, and the spec said the same thing in other words. One plan quoted the rule "search for the subject" and then listed four literal wordings. That list found three false hits and missed both stale statements. Twenty document findings followed over three reviews.

Rule: Search for the subject, not for the old wording, and read every hit.

## sweep-every-document

A decision changed in the spec. The sweep covered the spec only. The plan still told implementers to run a check that the spec now called worthless.

Rule: Amend every document where the decision appears, and name that set in the sweep step of the plan.

## facts-that-move

Three sentences in a rule file said that the project has no UI test target. That was true on one branch and false on another. In a second case, a token count in a document moved from 89 to 92 after a re-export. The team had called that count branch-varying. A re-export is not a branch, so the rule did not seem to apply.

Rule: Put a fact in the thing that changes with it. If anything can change a fact without a change to the document, the fact does not belong in the document.

## predicted-compile-order

A plan review counted four matches for one new type name. The implementer counted zero, because the build named a different type first. A plan can also prescribe a search that matches nothing on a green run. Then a passing build and a build that compiled nothing look the same. Three implementers hit this on their own.

Rule: The search in a red step matches any of the new type names, never one specific name.

## unsettled-screenshot

One screenshot was taken during a scroll. It showed what looked like a clipped view. A full fix round was needed to prove that the view was fine. A capture that waits only for "the view exists" starts too early.

Rule: Capture a screenshot only after two frames match. Use the capture command of the platform skill, not your own wait loop.

## logic-out-of-the-view

Scroll arithmetic in one screen moved into a pure function with unit tests. A reviewer then calculated all eleven expectations again by hand. A bubble that collapses to zero height became a value that a test can read. Before that, only a device showed the problem.

Rule: Put logic where a test can assert it. If you can assert a fact without a device, do so.

## ledger-skipped

One ticket kept no ledger, and nobody agreed to that. Its own retro records the gap. In another run, the retro claimed 23 commits and 317 tests. The real figures were 41 and 326. The final review caught it.

Rule: Every run keeps a ledger that names each commit, with no exemption.

## token-double-count

A run summed the tokens from 99 completion notices and got 32.7 million. The real figure was far lower. A resumed agent reports its running total again, so a sum counts it many times. A forecast built on that figure was wrong by a large factor.

Rule: Count each agent one time, at its final cumulative figure.

## fix-round-cost

A ticket with three tasks spent about five hours in review and fix. Its second round had one Important finding and several Minor findings. Each Minor finding restarted a proof run of 28 copies. Findings below Important added cost and did not add safety.

Rule: Critical and Important findings block. Write every other finding down as a follow-up.

## visual-fix-batching

On one ticket, the first two screen tasks used about one million tokens each. Most of their findings were about looks. Each fix round recorded every required snapshot again, and a later task often recorded them again anyway.

Rule: If a ticket has several view tasks, an Important visual finding goes to one visual fix task after the last view task. The plan can mark a screen as an exception.

## machine-state-first

A run had three theories in a row that blamed the branch. The machine held 117 orphaned test devices from years before. In the same period, a build showed no processor time for 582 seconds and was called dead. It finished 40 seconds later. Three more runs on that machine each took 40 seconds. Another run measured the disk size of cloned devices. The figure was an artefact, because the clones share blocks, and the free space did not change.

Rule: When a failure is not explained by the diff, count the accumulated state of the machine before you form a theory about the code.

## cpu-time-not-clock-time

A hung build ran for almost nine minutes of clock time and used 6.5 seconds of processor time. Its processor total stayed frozen. A different build looked idle by elapsed time and then finished. One task started the test command thirteen times in 38 minutes without trying anything new.

Rule: Judge a stalled run by processor time. Two dead builds in a row mean escalation, not a third attempt.

## guard-that-continues

A check printed "BUILD RUNNING, abort" and ten gigabytes of deletions ran anyway, because the check was an echo and not an exit. In three separate cases, an edit script stopped on an assertion and the commit after it still ran. The commit message then described a change that its own diff did not contain.

Rule: Write a guard as an exit, not an echo. If a scripted edit fails, abort the commit too.

## guessed-deletion

Four deletions hit live state in two days, across three sessions. An implementer deleted a live watch state folder as housekeeping. A reviewer ran a wildcard delete over a shared scratchpad. A process manager deleted a live work folder that it picked as the newest temporary directory. An implementer deleted a result bundle before anyone archived it. Each one chose its target by a guessed pattern or by recency.

Rule: Delete only a path that your own command printed.

## shell-differs

A lint round measured a byte order mark case with the shell search command. In the interactive shell that command is a function that calls a different tool with extra flags. The lint runs under the plain shell, which uses the system tool. The measured result was wrong and cost part of a fix round.

Rule: The shell is an input. Measure a script by running the script itself.

## scratch-path-probe

A spike ran in a throwaway worktree under a temporary directory. That directory is a symlink to another path. The sandbox rule named the first spelling, while real accesses used the second. The rule never matched, and the default allow rule let every read through. Both runs of the spike had no effect. The team wrote the conclusion into a spec as a measured fact. It cost an implementer seat.

Rule: Run a probe of anything path-sensitive at the real path where the code will be.

## stale-build-install

An agent found a build with a file search and installed it. The search returned an old build with the code of a previous branch. The agent then drove it against a real account. The report said that the current build was under test.

Rule: Get the build that you install from the output path that you just built into. If it is not there, stop.

## live-session-on-test-device

The test device held a real signed-in session. The team read that fact from the keychain and had not inferred it. A debug build on that device posted to a live backend. The launch smoke test started the app on every full run, so QA ran against a live account by default.

Rule: A device that holds a real session is not a test device. Never target it from automation.

## parallel-device-load

A wave of parallel implementers each booted their own device. The machine load multiplied. Load cost the team more time than any defect. Later, a QA task on the controller used one device and one task at a time claimed it.

Rule: Defer a device check to QA. Do not give each implementer a device.

## clean-merge-broken-build

Two branches merged with no text conflict. The merged tree did not compile. Every test on the base branch was blocked until the next ticket fixed it. A pre-merge check had read the merge tree and had not built it.

Rule: Build the merge result before you call it clean.

## checks-that-cannot-fail

A run shipped five pieces of evidence that had no way to fail. A parse gate exited 0 on a broken project file. A count returned 2 on the fix, on the defect, and on a build that never ran. A signing check used a listing taken before the run. A count of 3 stayed 3 after an edit to the wrong thing. One expected result asserted a single clause of a four-clause sentence, so it passed on both false statements that shipped.

Rule: A check names the value on a correct tree and the value on the defect that it excludes. Measure both.

## derived-not-measured

Two manual checks failed against correct behavior. One demanded that every pixel of a row match the ground colour, which a shadow makes impossible on any build. One described settling behavior that the change itself had altered. The author derived both from the constraints, and nobody ran either. In another run, four corrections were figures that the controller predicted and never ran.

Rule: If an expected result states a measurement, read it from a real run. Do not derive it.

## wrong-build-configuration

A spec check counted a control string in the release binary. The string was 15 bytes, and a release build holds no such text, so the check had no way to pass. The author wrote it at spec time and measured neither value in the release build. The ship step found the error. In another run, the plan review ran the checks that the plan runs. It did not run the checks that the plan wrote into a document for a later reader. One of them passed on a missing catalog and cost two fix rounds.

Rule: Measure each value in the build configuration that the check reads.

## fail-closed

A release-readiness check read a work folder. The folder disappeared during the run, and the check exited 0. A planted violation passed. Three reviews read the check. Nobody asked about the case where its input is gone.

Rule: If the input of a check is missing, the check must fail closed. Tell the reviewer to run each check against a copy that you broke on purpose.

## surviving-mutations

A reviewer deleted each production branch of a task to see whether a test went red. The task had 33 passing tests, and the path that every real run takes was untested. A mutation that reported every failure twice survived all of them. In another run, eight production mutations survived a drift suite. One changed a colour accessor to point at another token, and all 451 tests still passed.

Rule: When you remove the production code that a test covers, make sure that the test goes red. Cite a mutation that a review already ran. If the file changed, run it again.

## retro-proposes-only

One run proposed eighteen retro items, and fourteen of them were additions to one rule file. Two authors editing one untracked file leave git unable to restore the change. In another case, a rule changed while a plan that quoted the old wording waited for review. An hour later, three briefs were about to carry a rule that no longer existed. A reviewer who applied the new rule was set to fail work that matched its brief.

Rule: A retro proposes a rule change as an action item and never edits plugin files. A rule change goes as a pull request to the plugin repository.
