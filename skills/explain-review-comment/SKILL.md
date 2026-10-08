---
name: explain-review-comment
description: Judge whether a PR review comment (usually a pasted screenshot from GitHub or the IDE's PR review view) points at a real issue, explain it in simple terms, and offer a fix. Use when the user runs /explain-review-comment <image or text>, or pastes a review comment and asks "is this a real issue?" / "is this valid?" / "what does this mean?".
---

# Explain review comment

The user pastes a review comment (usually a screenshot, sometimes text) from a PR they're
reviewing or that's been reviewed. Decide whether it's a real issue, explain it plainly, and
offer a fix. This is advice: don't change code, commit, or reply on the PR until the user asks.

## Steps

1. **Read the comment.** From the screenshot, pick out the file path, line number, the
   highlighted code, the comment text, and the PR number or branch if shown. If the input is
   missing or unreadable, ask for it and stop.

2. **Check it against the real code.** Don't judge from the screenshot alone.
   - Open the file at that line in the local checkout. If the current branch isn't the PR's
     branch, read the file from the PR instead (`gh pr diff <n>` or
     `git show origin/<branch>:<path>`), and say which version you checked.
   - Test the comment's claim: trace the inputs, look at callers, validators, setters and
     existing tests. If the claim depends on how a client behaves (e.g. "the form sends empty
     strings"), find that client code, including sibling repos such as a frontend in a nearby
     directory.
   - Look for knock-on effects a fix would have (shared helpers, other constraints on the same
     field, persisted values).

3. **Give a verdict first**, in one bold line:
   - **Real issue**: it causes wrong behaviour today.
   - **Not an issue in practice**: the claim is technically true but nothing triggers it. Say
     why, and whether it's still worth hardening.
   - **Not an issue**: the comment is wrong. Say what it missed.

4. **Explain it in simple terms.** Explain it in a few sentences or bullets: what the code does,
   what input breaks it, and what the user or caller would see. Cite `file:line` and quote a few
   lines of code only when they make the point clearer. Avoid jargon the comment itself used
   without explaining it.

5. **Offer a solution.**
   - Real issue: the fix, including anything else it touches (e.g. another constraint that
     would still reject the same input), and the test you'd add.
   - Not an issue in practice: the options (leave as is or harden), the trade-off of each, and
     a recommendation.
   - Not an issue: a short reply the user could post on the comment.

6. **End with an offer** in one line: implement the fix and add a test, and/or reply on the
   comment. When the user later asks you to reply, post it as a threaded reply to that comment
   (`gh api repos/<owner>/<repo>/pulls/<n>/comments/<id>/replies`). Match any prefix the
   original comment used (e.g. `🤖 Claude:`), and say whether the fix is pushed yet.

## Rules

- Read-only until the user asks for more.
- Be decisive: give one verdict and one recommendation, not a survey of options.
- Keep it short. The user is mid-review and wants the answer, not a report.
