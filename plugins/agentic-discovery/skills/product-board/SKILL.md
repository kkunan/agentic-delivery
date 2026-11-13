---
name: product-board
description: Log each read of the product numbers and the decision that follows it, and show both on one board page. Use it for a product dashboard, a read of the analytics, a decision log, or a goal check. It holds the row shapes, the rules for a read, and the goal check. It also holds a plain HTML board with made-up data.
---

# Product board

A board has two parts. The numbers show what users did. The log shows each read of the numbers, your pick, and the decision of a person.

1. Read `log.md`. It gives the row shapes and the rules for each read.
2. Find the numbers. If the session has a connector that can query the source, such as a data warehouse, use it. If not, read the analytics reports by hand. Write down the report, the date range, and the filter of each number.
3. Write one log row for each question that the numbers raise. Fill every field that you can fill. A field with no data says "no data".
4. Build the page. If the account has a Dashboard artifact type, use it, with one dataset for each list in the data block of `board.html`. If not, copy `board.html` and replace its data block with your counts, steps, and rows.
5. Show the owner each row that waits on them, in the chat, one question in each message. After each answer, change that row and the page.

The sample data in `board.html` is for a made-up savings app. If the skill `public-writing` is installed and the page is for people outside the team, load it first.

## A goal check

If the owner asks how the numbers stand against the goals, for example each week, build a goal check. The section The goal check in `log.md` gives the table and its rules. Show the table in the chat first. Put it on a page or a ticket only after the owner says yes. A row with "Miss" or "Borderline" can raise a question. Write it as a log row.
