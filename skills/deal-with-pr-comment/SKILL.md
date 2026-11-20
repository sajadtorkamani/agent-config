---
name: deal-with-pr-comment
description: Deal with one PR review comment end to end on the PR's own branch - checks whether it's valid and worth fixing, and if not, stops and explains why; otherwise fixes it, commits, pushes, replies on the comment and resolves the thread. Takes a link to the comment or a screenshot of it. Use when the user runs /deal-with-pr-comment <link or image>, or pastes a review comment and says "fix this and then commit & push & reply & resolve" or similar.
allowed-tools: Skill, Read, Write, Edit, Glob, Grep, Bash
---

# Deal with PR comment

The user hands you one review comment on one of their PRs, as a link
(`https://github.com/<owner>/<repo>/pull/<n>#discussion_r<id>`) or a screenshot. Decide whether it's
worth fixing. If it is, fix it straight on the PR's branch, commit, push, reply on the comment and
resolve the thread. If it isn't, stop and explain why, changing nothing.

This differs from `address-pr-comment`, which puts each fix in its own stacked patch PR. Here the
fix goes on the PR's branch directly.

## Step 1 - Find the comment

- **Link**: take `<owner>/<repo>`, the PR number and the comment id (the number after
  `discussion_r`) from it, then fetch the comment:
  `gh api repos/<owner>/<repo>/pulls/comments/<id> --jq '{id, path, line, body, in_reply_to_id, html_url}'`.
- **Screenshot**: pick out the file path, line, highlighted code and comment text. Find the PR from
  the screenshot, or else the current branch's PR (`gh pr view --json number,url,headRefName`).
  Find the comment id by matching path, line and the start of the body:

  ```bash
  gh api --paginate repos/<owner>/<repo>/pulls/<n>/comments \
    --jq '.[] | select(.in_reply_to_id == null) | {id, path, line, body: .body[0:120]}'
  ```

If the input is unreadable, the PR is ambiguous or two comments match equally well, ask and stop.
If the comment is a reply, use its `in_reply_to_id` as the comment to reply to.

Find the review thread id, needed to resolve it later:

```bash
gh api graphql -f query='query{repository(owner:"<owner>",name:"<repo>"){pullRequest(number:<n>){reviewThreads(first:100){nodes{id isResolved comments(first:1){nodes{databaseId}}}}}}}' \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.comments.nodes[0].databaseId == <comment-id>) | {id, isResolved}'
```

If the thread is already resolved, say so and ask before doing anything.

## Step 2 - Check you're on the PR's branch

Run `git rev-parse --abbrev-ref HEAD` and compare it with the PR's head branch.

- **Same branch**: carry on. Run `git fetch` and stop if the local branch is behind its remote,
  so the push won't be rejected. Note any uncommitted changes already there: they aren't yours,
  so leave them out of the commit.
- **Different branch**: don't switch the user's checkout. Ask whether to switch, or to do the fix
  in a worktree on the PR's branch, and wait for the answer.

## Step 3 - Judge it

Check the claim against the real code, not the screenshot alone: open the file at that line, trace
inputs, callers and tests, and read any rule the comment quotes (CLAUDE.md, AGENTS.md, docs) to
confirm it says what the comment claims. Then pick one:

- **Valid and worth fixing**: say so in one line and go to Step 4. A cheap, clear-cut nit counts.
- **Not an issue**: the comment is wrong. Stop. Say what it missed, citing `file:line`.
- **Not worth fixing**: true, but the fix costs more than the risk or goes against a decision
  already made. Stop. Explain why in a few plain sentences.

When you stop, don't change code, reply or resolve. Offer one line the user could post as a reply,
and post it only if they ask.

If the comment raises several points, check each one. Fix the valid ones, and say which you left
and why. If a point is a judgement call the user should make, ask before fixing.

## Step 4 - Fix and verify

Make the smallest change that addresses the comment and nothing else: no drive-by refactors. Follow
the repo's CLAUDE.md / AGENTS.md conventions. If the same problem appears elsewhere in the PR's
changes, fix those too, since the reviewer would raise them next.

Run the tests that cover the change, following the repo's instructions for how to run them. A
comment-only or docblock-only change doesn't need tests. If you can't run them, say so in the
report and in the reply.

## Step 5 - Commit and push

Stage only the files you changed (`git add <paths>`), then commit with the `commit` skill's message
rules (a Conventional Commits title with the ticket as scope, e.g.
`test(DEV-569): use typed fixture helpers`). No attribution trailers. Then:

```bash
git push
```

Never force-push. If the push is rejected, stop and report it.

## Step 6 - Reply and resolve

Reply in the comment's thread, saying what changed and naming the commit. The reply posts under the
user's name, so end it with a blank line and `_Claude Code on behalf of Sajad_`, with no
`🤖 Claude` prefix, even if the original comment has one:

```bash
gh api repos/<owner>/<repo>/pulls/<n>/comments/<comment-id>/replies \
  -f body="Fixed in <short-sha>: <what changed, in a sentence or two>.

_Claude Code on behalf of Sajad_" --jq .html_url
```

Then resolve the thread:

```bash
gh api graphql -f query='mutation{resolveReviewThread(input:{threadId:"<thread-id>"}){thread{isResolved}}}' \
  --jq .data.resolveReviewThread.thread.isResolved
```

Put the ids into each command literally. Don't split one shell variable into two ids: zsh doesn't
word-split unquoted variables, so `set -- $ids` leaves them joined.

## Step 7 - Report

Keep it short:

- The verdict and what changed, with `file:line` references.
- What you ran to verify it, and the result.
- The commit title and short hash, and that it's pushed.
- The reply's URL, and that the thread is resolved.

## Rules

- One comment per run. If the user hands over several, deal with them one after another, each with
  its own commit, reply and resolve.
- Change nothing, reply to nothing and resolve nothing when the verdict is "not an issue" or "not
  worth fixing".
- Never force-push, switch the user's branch without asking, or commit changes that aren't yours.
