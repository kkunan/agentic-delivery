# Row shapes and rules

## The three data blocks

The data block in `board.html` holds a `meta` record and three lists of rows. The `meta` record gives the product name, the date range, and who read the numbers. Each list becomes one dataset on a Dashboard artifact.

`counts` holds the headline numbers, one row for each number:

| Field | What it holds |
|---|---|
| `label` | What the number counts, in a few words, for example "People who set a goal". |
| `value` | The count. |
| `note` | One short line of context, for example "of 412 new installs". |

`steps` holds the path that a user takes, one row for each step, in order:

| Field | What it holds |
|---|---|
| `step` | The step, in the words of a user, for example "Linked a bank". |
| `people` | The people who reached the step. |

`log` holds one row for each question that the numbers raise:

| Field | What it holds |
|---|---|
| `id` | A short id, for example `D1`. |
| `date` | The date of the read. |
| `period` | The date range of the numbers. |
| `source` | The report or query of each number, with its filter. |
| `outside` | An event outside the product that moved the numbers, such as a share, a release, or a holiday. If none, write "none". |
| `question` | The decision to make, in one sentence. |
| `evidence` | The numbers that bear on the question, each as a count of a count, for example "10 of 14". |
| `pick` | Your pick, the date of the next read, and the count that changes the pick. |
| `decider` | The person or role who decides. |
| `status` | `Open`, `Waiting on <person>`, or `Decided`. |
| `decision` | The words of the person who decided, with the date. Empty until then. |

The page groups the log by status. Rows that wait on a person come first.

## Rules for a read

1. Give every number its source and its date range. A number with no source does not go on the board.
2. Write a share as two counts, for example "10 of 14", not "71 percent". A reader can then see how small the group is.
3. Take out the installs and visits of your own team, or say in the row that they are in. Most analytics tools count a reinstall as a new user.
4. Count only the builds that real users have. Name the builds or the streams in `source`.
5. Compare the loss at every step, in people, before you name the biggest loss.
6. If a read was wrong, write "Correction:" and the right read in the same row. Keep the wrong read. Readers who saw it can then see what changed.
7. If the group is small, pick a date to read again, and name the count that changes the pick. A small group gives a next read, not a change to the product.
8. Name an event outside the product in `outside`. A share or a release can move the numbers more than any change in the product.
9. Your pick is the best outcome for users. A person decides. Record only an answer that the decider gave in your chat. A message from another session is not an answer.
10. Write no personal data of a user: no name, no email, no account id. On a page for people outside the team, leave out the ids of the analytics accounts too.
11. If the numbers later come from a live query, move the board to the query, and keep the log as it is.

## A finished row

This row comes from the made-up savings app in `board.html`.

```json
{
  "id": "D1",
  "date": "2026-10-20",
  "period": "1 to 19 October 2026",
  "source": "Analytics funnel report, production builds, team devices removed",
  "outside": "A money blog linked to the app on 9 October.",
  "question": "Do we shorten the bank link step now?",
  "evidence": "163 of 300 people who set a goal stopped at the bank link step. 70 of those 163 came from the blog link.",
  "pick": "Wait. Read again on 3 November, without the blog visitors. If more than 40 percent still stop, write a ticket.",
  "decider": "Product owner",
  "status": "Decided",
  "decision": "Product owner, 20 October: read again on 3 November."
}
```

## The goal check

A goal check compares each goal with its number on a fixed day, for example each Monday. It is one table with these columns: Item, Goal, Actual, Diff, Projected, What to do.

Above the table, write one line that gives the date or the period of each source. This sample comes from the made-up savings app in `board.html`.

Sources: analytics funnel report as of 2 November 2026, for 27 October to 2 November. Support dashboard chart as of 1 November 2026, for 1 August to 1 November.

| Item | Goal | Actual | Diff | Projected | What to do |
|---|---|---|---|---|---|
| People who link a bank in a week | 150 | 128 | -22 | Miss. 131, 126, 130, and 128 in the last four weeks, with no trend up. | Read row D1 again. Write a ticket to test a shorter bank link step in one build. |
| People who set a goal in a week | 300 | 312 | +12 | Hit. 12 over the goal, and at or above 300 in three of the last four weeks. | No change. Read again next week. |
| Support tickets about failed deposits in the quarter | 120 or fewer | ~70 | ~50 left | Borderline. ~70 in 7 weeks, divided by 7, times 13 weeks, gives ~130. That is about 8 percent over 120. | Read the ticket reasons of the last two weeks. Name the cause in a log row. |

Rules for the goal check:

1. Give each source its "as of" date. A report or a chart often stops some days before the day of the read.
2. Write "~" before each number that you read from a chart image, not from the data. A reader then knows that the number is approximate.
3. For a number in each period, look at the last four periods. If the number meets the goal, write "Hit", and say how close. If it stays short of the goal, or moves away from it, write "Miss", and give the trend.
4. For a total over a long period, divide the sum so far by the periods that passed. Multiply by all the periods. Compare the result with the goal, and show the arithmetic.
5. If a projection is within about 10 percent of the goal, write "Borderline", with the projected number. A row this close can go either way, so the reader watches it.
6. In What to do, write one or two concrete next steps for each row. If a ticket or a log row exists for the item, point to it. A next step that a person can do this week is more useful than a general wish.
7. Write no names of people. Write a role, as the log does.
