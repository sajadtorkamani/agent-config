---
name: address-pr-comment
description: Address one PR review comment (usually a pasted screenshot from GitHub) with a stacked patch PR — judges whether the issue is worth fixing (asks first if it's an edge case), fixes it in a worktree on a `<original-branch>--patch-<slug>` branch, opens a draft PR into the original PR's branch, replies on the review comment with the patch PR link, and replies again once the patch is merged. Use when the user runs /address-pr-comment <image or text>, or asks to "address", "patch" or "fix" a specific review comment in its own PR. Also use with a patch PR link to post the "patch merged" reply.
allowed-tools: AskUserQuestion, Skill, EnterWorktree, ExitWorktree, Read, Write, Edit, Glob, Grep, Bash
---

# Address PR comment

The user is working through review comments on a PR, one at a time. For each comment they paste,
decide whether it's worth fixing, and if it is, fix it in its own small PR stacked on the original
PR's branch. That keeps each fix reviewable on its own and leaves the user's checkout alone.

The user may run this several times in a row for different comments on the same PR, so every patch
gets its own worktree, branch and PR. Never fold two comments into one patch unless the user asks.

## Step 1 — Read the comment and find the PR

From the screenshot or text, pick out the file path, line number, highlighted code, the comment
text and author, and any PR number or branch shown. If the input is missing or unreadable, ask for
it and stop.

Find the original PR. If the screenshot doesn't show it, use the current branch's PR
(`gh pr view --json number,url,headRefName,baseRefName,state`). If that's ambiguous or there's no
open PR, ask. Capture `<owner>/<repo>`, the PR number and its head branch (the "original branch").

Find the review comment's id, since both replies thread onto it:

```bash
gh api --paginate repos/<owner>/<repo>/pulls/<n>/comments \
  --jq '.[] | {id, path, line, user: .user.login, body: .body[0:120]}'
```

Match on path, line and the start of the body. If two comments look equally likely, ask which one.
Reply only to a top-level comment (one with no `in_reply_to_id`); if the match is itself a reply,
use its `in_reply_to_id`.

## Step 2 — Judge it

Check the claim against the code on the PR's branch (`git show origin/<branch>:<path>`, or the local
file if the user is on that branch), not the screenshot alone. Trace the inputs, callers, validators
and existing tests, as `explain-review-comment` does.

Then pick one of three outcomes:

- **Clearly worth fixing** — it causes wrong behaviour in a realistic case, or it's a missing test
  for new logic that could easily regress. Say so in one or two sentences and go straight to Step 3.
- **Edge case or debatable** — technically true but unlikely to bite, or the fix costs more than the
  risk. Stop and ask. Explain in plain terms: what the code does, what input would break it, how
  likely that is, and what the fix would involve. Then ask with `AskUserQuestion` whether to patch
  it, with your recommendation first. Don't create anything until they answer.
- **Not an issue** — the comment is wrong. Say what it missed, offer a short reply for the comment
  thread, and stop. Post the reply only if the user asks.

If the user declines a fix, offer to reply on the comment explaining why it's being left, and stop.

## Step 3 — Create the patch worktree

The patch branch must start from the **remote** tip of the original branch, so check it's current
first:

```bash
git fetch origin <original-branch>
```

If the user's local copy of the original branch has commits that aren't pushed, or uncommitted
changes in files the fix touches, say so before continuing. The patch is built on what's on the
remote, so those changes won't be in it.

Call `EnterWorktree` with a short name for the patch (e.g. `patch-compass-inviter-tests`). Then
rename the branch and point it at the original branch:

```bash
git branch -m <original-branch>--patch-<slug>
git reset --hard origin/<original-branch>
git log --oneline -1
```

`<slug>` is a short kebab-case description of the fix, e.g. `feature/DEV-101-new-login-page` becomes
`feature/DEV-101-new-login-page--patch-fix-password-validation`. If the name already exists locally
or on the remote, add a suffix.

A fresh worktree has no gitignored files. Copy env files and install dependencies only if you need
them to run tests, following the repo's CLAUDE.md for how to run things (some repos run tests in a
container and have their own recipe for worktrees).

## Step 4 — Fix and verify

Make the smallest change that addresses the comment. Stay inside it: no drive-by refactors, since
the user reviews each patch on its own. Follow the repo's conventions and CLAUDE.md. Add or update a
test for the fix where it makes sense.

Run the relevant tests, lint or type checks. If you can't get the project running in the worktree,
carry on, but say clearly in the PR and the report that the change is unverified.

## Step 5 — Commit, push, open the PR

Commit with the `commit` skill (Skill tool, `skill: commit`), then `git push -u origin HEAD`. If the
push is rejected, stop and report it; never force-push.

Write the PR body to a file in the scratchpad (or `${TMPDIR:-/tmp}`), not inline. Keep it short:

- A link to the review comment it addresses (the comment's `html_url`) and to the original PR.
- What was wrong and what changed, in a couple of sentences or bullets.
- What you verified, and anything you couldn't.

```bash
gh pr create --draft \
  --base "<original-branch>" \
  --title "<conventional-commit title, same format as the commit skill>" \
  --body-file "<scratchpad>/address-pr-comment/<slug>.md" \
  --assignee @me
```

Open it as a draft and leave it that way; the user marks it ready when they're happy with it. Don't
request AI reviews unless asked.

## Step 6 — Reply on the review comment

Post a threaded reply on the original comment:

```bash
gh api repos/<owner>/<repo>/pulls/<n>/comments/<comment-id>/replies \
  -f body="A patch for this has been created in <patch-pr-url>.

_Claude Code on behalf of Sajad_"
```

The reply posts under the user's name, so end it with a blank line and then the italic
`_Claude Code on behalf of Sajad_` sign-off. Don't add a `🤖 Claude (<model>): ` prefix. Don't
resolve the conversation; the user does that.

## Step 7 — Watch for the merge

Start a background watcher (Bash with `run_in_background: true`) so you're re-invoked when the patch
PR closes:

```bash
while state=$(gh pr view <patch-pr-url> --json state -q .state); [ "$state" = "OPEN" ]; do
  sleep 120
done
echo "$state"
```

When it finishes:

- **MERGED** — reply on the same review comment thread:
  `The patch in <patch-pr-url> has been merged.`, ending with the same sign-off. Then remove the worktree
  (`git worktree remove <path>`) if it has no uncommitted changes, and tell the user in one line.
- **CLOSED** without merging — don't comment. Tell the user and ask whether to reply on the thread.

The watcher only lives as long as this session. If the session ends first, the user can run
`/address-pr-comment <patch-pr-url>` later: when the argument is a PR whose branch contains
`--patch-`, skip straight to this step. Find the review comment from the link in the patch PR's
body, check the PR is merged, check the thread doesn't already have a "has been merged" reply, then
post it.

## Step 8 — Hand back

Leave the worktree with `ExitWorktree` (`action: "keep"`) so the session returns to the user's
checkout, then report briefly:

- The verdict in one line and what the patch changes.
- What you verified and what you couldn't.
- That the comment reply was posted and the merge watcher is running.
- The worktree path and branch.

End with the patch PR URL on its own line as plain text (no backticks or markdown link), e.g.
`PR: https://github.com/<owner>/<repo>/pull/<number>`.

## Rules

- Never touch the user's checkout: no commits, branch switches or stashes there.
- Never force-push, merge a PR, mark a patch PR ready for review, or resolve a review thread.
- One comment, one patch branch, one PR.
- No Claude attribution or co-author trailers in commits or PR bodies. The
  `_Claude Code on behalf of Sajad_` sign-off on comment replies is the only attribution.
