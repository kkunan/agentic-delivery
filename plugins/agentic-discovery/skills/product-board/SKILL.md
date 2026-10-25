---
name: product-board
description: Log each read of the product numbers and the decision that follows it, and show both on one board page. If someone asks for a product dashboard, a read of the analytics, or a decision log, use it. It holds the row shapes, the rules for a read, and a plain HTML board with made-up data.
---

# Product board

A board has two parts. The numbers show what users did. The log shows each read of the numbers, your pick, and the decision of a person.

1. Read `log.md`. It gives the row shapes and the rules for each read.
2. Find the numbers. If the session has a connector that can query the source, such as a data warehouse, use it. If not, read the analytics reports by hand. Write down the report, the date range, and the filter of each number.
3. Write one log row for each question that the numbers raise. Fill every field that you can fill. A field with no data says "no data".
4. Build the page. If the account has a Dashboard artifact type, use it, with one dataset for each list in the data block of `board.html`. If not, copy `board.html` and replace its data block with your counts, steps, and rows.
5. Show the owner each row that waits on them, in the chat, one question in each message. After each answer, change that row and the page.

The sample data in `board.html` is for a made-up savings app. If the skill `public-writing` is installed and the page is for people outside the team, load it first.
