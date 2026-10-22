---
name: qa-roam-tasks
description: QA every top-level item in the `QA` block of a Roam task page (my 'Task' template) - test each one in the running app (or through the API or automated tests when the app can't show it), then write a `QA result` block with the evidence under each item, re-checking and updating results from earlier runs and flagging items that no longer make sense. Use when the user runs /qa-roam-tasks [page title], or asks to QA / test / verify the items in QA on their Roam task page.
---

# QA Roam tasks

Test each top-level item in the `QA` block of a Roam task page, then record the result and the
evidence under the item in Roam. Follow `~/code/agent-config/roam-research-workflow.md` for how task
pages work, how to call the Roam API and the exact format of `QA result` blocks.

## Steps

1. **Find the task page.**
   - Use the page title passed to `/qa-roam-tasks`, if any. Otherwise use the Roam task page
     already discussed in this session.
   - If neither gives a page, ask for its title (and graph, if my instructions don't name one). Don't search
     the graph for one.

2. **Read the page.** Run `~/code/agent-config/scripts/roam-api.sh -g <graph> outline "<page title>"`.
   - The items to QA are the **top-level** blocks under `Subtasks` > `QA`. Their child blocks
     (sub-items, notes, examples, screenshots) describe what to check. Download any images and look
     at them.
   - Also read `Notes` on the page. A later decision there can replace what an item says.
   - If `QA` is empty, say so and stop.
   - Note any `QA result` blocks already under an item: those are from an earlier run (see step 6).

3. **Understand the change.** Before testing, read the code the items cover (in every repo the
   task touches, e.g. frontend and API) and the work done earlier in this session. Work out what
   each item should do and what data shows it.

4. **Judge each item before testing it.** Flag an item as problematic when:
   - it contradicts a later decision in `Notes` or in this session (e.g. a UI approach that was
     replaced),
   - it describes behaviour the code no longer has, or names fields, pages or options that have
     changed, or
   - it's too vague, or contradicts another item, so that you can't tell what passing means.

   Still test whatever part of it can be tested against the current intent, but the result is
   `Problematic task`. Don't mark an item problematic only because its wording differs slightly
   from the UI: if the intent is clear and met, it passes, and the evidence can mention the
   difference.

5. **Test each item.** Prefer testing it in the running app, the way a user would.
   - Follow the project's instructions for local manual testing (which URL to use, which user and
     company to log in as). Work out the expected result from the local database with read-only
     queries **before** looking at the app, then compare.
   - Use a fresh browser tab (see the browser tips below). Try edge values where the item has
     thresholds or boundaries (e.g. exactly 33% for a "33 to 66" rule), using filters or other
     local data to reach them.
   - When the app can't show it (e.g. no local data for the case, or behaviour that only shows at
     scale), verify it another way and say which: an API request, or an automated test you read and
     ran. Name the test.
   - For "all tests pass" style items, run the full suites (start them in the background early).
   - If your local data can't show something and there's no test for it, don't create or change
     data. Mark it `Partly verified` and suggest the smallest local change that would let me test
     it.
   - If you switch company, change settings or change anything else in the app to test, put it
     back afterwards.
   - Don't fix bugs you find in this skill. Record them as failures and offer to fix them at the
     end.

6. **Write the results to Roam.** Build one `batch-actions` body for the whole run and send it
   with `roam-api.sh write`. Use the format in the workflow notes: under each item, one
   `QA result: <status>` block with an `Evidence` child (or a `Why` child for problematic tasks)
   listing the steps you took, in order, with the data you used and what you saw.
   - **Re-running:** if an item already has a `QA result` block from an earlier run, QA it again
     from scratch. Then update that block's text with the new status, delete its old `Evidence` or
     `Why` child (deleting a block deletes its children), and add a fresh one. Never add a second
     `QA result` block to an item.
   - Fetch the page again just before writing, and address blocks by uid. I may have moved items
     (e.g. into `DONE`) or edited them while you were testing. Only write results for items that
     were under `QA` when you started, wherever they are now, and mention any that moved.
   - Only add or update `QA result` blocks and their children. Don't change the items themselves,
     their `TODO`/`DONE` markers or their position.
   - Read the page back afterwards and check every item has exactly one `QA result` block.

7. **Report.** In the conversation, give:
   - A table of every item with its status and how you checked it (in the app, by API, by an
     automated test, or in git).
   - Each failure: what you expected, what happened, and how to reproduce it. Offer to fix them.
   - Each problematic task: why, and a suggested rewrite or what to remove.
   - Anything only partly verified, and the smallest change that would let me test it fully.
   - Anything you noticed that isn't covered by an item but looks wrong (e.g. an edge case).
   - Paths to the screenshots you saved, and anything you changed and put back (e.g. the company).

## Browser tips

- Wait for real content before reading the page: loading skeletons can contain invisible
  characters, so wait for an element that only renders once the data has loaded.
- Data fetched in the last few minutes may come from the query cache, so no request is sent.
  Reload the page after you start reading network requests if you need to see a request.
- Keep query strings out of values you return from JavaScript (the browser tool may redact them).
  Return `URLSearchParams` values as separate fields instead.
- If resizing the window has no effect (check `innerWidth`), load the page in a same-origin
  `<iframe>` with a fixed width (e.g. 390px for a phone and 768px for a tablet) and test inside it.
  Check the page itself doesn't scroll sideways and that the filters and popovers fit on screen.
- If faking API responses in the browser causes reloads or errors, stop and use another way to
  check it. Don't sink time into it.
- Close the tabs you opened, and restore the window size if you changed it.

## Rules

- Never print the Roam API token or the contents of `~/.config/roam/`. Only call the API through
  `roam-api.sh`.
- Only run read-only queries against databases, including local ones.
- Be honest about how each item was checked. A result is only `Passed` if you saw it work (in the
  app, or through a test or API call that covers it). Otherwise use `Partly verified`.
