---
name: request-reviews
description: Get AI reviews on a GitHub PR from every reviewer I use — comments `@codex review` for Codex, requests Copilot as a reviewer, and, once those two have posted, runs Claude's `/code-review` with its inline comments prefixed `🤖 Claude:` (so they're clearly Claude's even though they post under my name) and told to skip issues Codex or Copilot already raised. Use when the user runs /request-reviews [pr], asks to get reviews on a PR, or wants the AI reviewers re-run after pushing fixes. Also called by delegate-task.
allowed-tools: AskUserQuestion, Skill, Bash
---

# Request reviews

Put every AI reviewer on a PR in one go, so the user opens it to find Codex, Copilot and Claude
have all had a look. It works on any PR — ones `delegate-task` opened, ones the user opened by
hand — and it's safe to run again after pushing fixes to get a fresh round.

Codex and Copilot are GitHub apps that review independently, so nothing stops them overlapping with
each other. Claude's review is the one this skill controls, so it runs **last** and is handed a
compact list of what's already been raised, so it doesn't post the same issue a third time.

## Step 0 — Find the PR

The PR comes from the arguments: a number (`26`) or a full URL. With no argument, use the current
branch's PR:

```bash
gh pr view [<pr>] --json url,number,headRefName,isDraft,state
```

If there's no PR for the branch, or the PR isn't open, stop and say so — there's nothing to review.
Capture the URL and number, and `<owner>/<repo>` from the URL (`https://github.com/<owner>/<repo>/pull/<number>`);
everything below uses them. Use the explicit `<owner>/<repo>` in `gh api` paths rather than
`{owner}/{repo}`, since some of the commands below run in the background, where the working
directory isn't guaranteed to be the repo.

Record the time now, as the start of this round: `date -u +%Y-%m-%dT%H:%M:%SZ` (call it
`<round start>`). Step 3 uses it to tell this round's bot reviews from earlier ones.

## Step 0b — Pick a checkout of the PR for Claude's review

Claude's review takes the diff from GitHub but reads the surrounding code (callers, helpers,
config) from local files. Against the wrong branch it misses bugs and flags code that does exist
on the PR as missing. So pick a checkout that has the PR's code — the first of these that applies
— and call its absolute path the **review dir**. Never switch branches in, or otherwise touch, the
user's current checkout.

1. **The current checkout is on the PR's branch** — `git rev-parse --abbrev-ref HEAD` equals
   `headRefName`. The review dir is `git rev-parse --show-toplevel`.
2. **A worktree already has the branch checked out** (e.g. one `delegate-task` made) — look for
   `branch refs/heads/<headRefName>` in `git worktree list --porcelain`. The review dir is that
   entry's `worktree` path.
3. **Otherwise, create a temporary worktree** at the PR's head commit, outside the repo so it
   never shows up as untracked files. `pull/<number>/head` works for PRs from forks too, and
   `--detach` avoids clashing with a branch of the same name checked out elsewhere:

   ```bash
   git fetch origin "pull/<number>/head"
   REVIEW_DIR="$(mktemp -d)/pr-<number>"
   git worktree add --detach "$REVIEW_DIR" FETCH_HEAD
   ```

   Remember that this run created it — Step 3 removes it when the review finishes.

If the fetch or `worktree add` fails, say so in one line and fall back to the current checkout as
the review dir, noting that Claude's review can only fully trust the diff.

## Step 1 — Codex

Post a comment so the Codex GitHub app reviews the PR:

```bash
gh pr comment <url> --body "@codex review"
```

The body has to be exactly that — the app triggers on the mention, and extra prose around it can
stop it firing. If the comment fails, or the Codex app isn't installed on the repo so nothing reacts
to it, don't retry: say so in one line and move on.

## Step 2 — Copilot

Request Copilot as a reviewer. Automatic Copilot review may skip drafts, so don't rely on it:

```bash
gh pr edit <url> --add-reviewer @copilot
```

On a PR Copilot has already reviewed, this re-requests a review. If it fails (older `gh`, or Copilot
code review not enabled for the repo), don't retry: say so in one line and move on.

## Step 3 — Claude

Run Claude's own review so its findings sit alongside Codex's and Copilot's, without repeating them.

The comments are posted with the user's own GitHub login, so they show up under the user's name.
To make it obvious they came from Claude, every comment this review posts must start with
`🤖 Claude: ` (emoji, the word Claude, a colon, a space).

### 3a — Wait for Codex and Copilot

Wait only for the reviewers that Steps 1–2 actually triggered. If neither was, skip to 3b straight
away.

Otherwise start this as a **background** Bash command (`run_in_background: true`) — it's a cheap
shell loop, not model work, and the harness re-invokes you when it exits. Drop the check for a
reviewer that wasn't triggered:

```bash
since="<round start>"; deadline=$(( $(date +%s) + 900 ))
codex_done() {
  [ "$(gh api "repos/<owner>/<repo>/pulls/<number>/reviews" --paginate \
        --jq "[.[] | select(.user.login == \"chatgpt-codex-connector[bot]\" and .submitted_at >= \"$since\")] | length")" != 0 ] ||
  [ "$(gh api "repos/<owner>/<repo>/issues/<number>/comments" --paginate \
        --jq "[.[] | select(.user.login == \"chatgpt-codex-connector[bot]\" and .created_at >= \"$since\")] | length")" != 0 ]
}
copilot_done() {
  [ "$(gh api "repos/<owner>/<repo>/pulls/<number>/reviews" --paginate \
        --jq "[.[] | select(.user.login == \"copilot-pull-request-reviewer[bot]\" and .submitted_at >= \"$since\")] | length")" != 0 ]
}
until { codex_done && copilot_done; } || [ "$(date +%s)" -ge "$deadline" ]; do sleep 30; done
codex_done && echo "codex: done" || echo "codex: timed out"
copilot_done && echo "copilot: done" || echo "copilot: timed out"
```

Codex counts as done once it posts a review *or* a top-level comment, since it reports "no major
issues" and errors as comments rather than reviews. The 15-minute cap means a reviewer that never
shows up (app not installed, review failed silently) only delays Claude, never blocks it.

Don't wait in the foreground — go on to Step 4 and report, then continue with 3b when the
background command finishes.

### 3b — Collect what's already been raised

Fetch the PR's **unresolved** inline review threads in one compact listing — first comment of each,
truncated. This covers Codex's and Copilot's comments from this round, plus anything still open from
earlier rounds (including Claude's own), so a re-run after pushing fixes doesn't re-raise those
either:

```bash
gh api graphql -F owner=<owner> -F repo=<repo> -F number=<number> -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) { pullRequest(number: $number) {
      reviewThreads(first: 100) { nodes { isResolved path line originalLine
        comments(first: 1) { nodes { author { login } body } } } } } } }' \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved | not)
        | .comments.nodes[0] as $c
        | "\(.path):\(.line // .originalLine) [\($c.author.login)] \($c.body
            | gsub("!\\[[^\\]]*\\]\\([^)]*\\)"; "") | gsub("<[^>]+>"; "") | gsub("\\s+"; " ") | .[0:200])"'
```

The truncation keeps this to a few thousand tokens at most; don't fetch full bodies. If the
listing is empty, run 3c without the dedupe instruction.

### 3c — Run the review

1. Record the time just before launching, for step 3: `date -u +%Y-%m-%dT%H:%M:%SZ`.
2. Invoke the `code-review` skill (Skill tool, `skill: code-review`) with
   `args: "high --comment <url>"`. Always pass the level explicitly — without one, the review
   reuses whatever level the user last typed, so reviews would get inconsistent depth. The args
   can't carry extra instructions (everything after the level and flags is read as the review
   target), so state these rules in your own words just before invoking it:
   - "Start every comment you post on the PR with `🤖 Claude: `."
   - "Read the PR's code from `<review dir>`, not the current working directory: open files by
     their absolute paths under it and run git and other commands with `cd <review dir> &&` or
     `git -C <review dir>`."
   - "These unresolved comments are already on the PR (some may be the author's own notes rather
     than issues): <the 3b listing>. Review the whole PR as normal,
     but don't post a finding with the same root cause as one of these, even if it's on a
     different line or worded differently. Only skip it when you're confident it's the same
     issue — if unsure, post it. A finding about the same code but a different defect is not a
     duplicate."

   The review runs as a forked background agent that inherits this context, so it should see all
   three.
3. The review runs in the background and its result arrives later as a task notification. Don't
   wait for it. When the notification arrives, make
   sure every comment it posted is prefixed. Fetch the user's comments on the PR created since the
   recorded time — inline review comments, review bodies, and top-level comments:

   ```bash
   ME="$(gh api user -q .login)"
   gh api "repos/{owner}/{repo}/pulls/<number>/comments" --paginate \
     --jq ".[] | select(.user.login == \"$ME\" and .created_at >= \"<since>\") | {id, body}"
   gh api "repos/{owner}/{repo}/pulls/<number>/reviews" --paginate \
     --jq ".[] | select(.user.login == \"$ME\" and .submitted_at >= \"<since>\" and .body != \"\") | {id, body}"
   gh api "repos/{owner}/{repo}/issues/<number>/comments" --paginate \
     --jq ".[] | select(.user.login == \"$ME\" and .created_at >= \"<since>\") | {id, body}"
   ```

   For each one whose body doesn't already start with `🤖 Claude:`, prepend `🤖 Claude: ` and save
   it back — `PATCH repos/{owner}/{repo}/pulls/comments/<id>` for inline comments,
   `PUT repos/{owner}/{repo}/pulls/<number>/reviews/<id>` for review bodies,
   `PATCH repos/{owner}/{repo}/issues/comments/<id>` for top-level comments, each with
   `-f body=<new body>`. Leave any `@codex review` trigger comment alone — editing it can stop
   Codex picking it up. Then tell the user in one line how many findings Claude posted and that
   they're prefixed.
4. If Step 0b created a temporary worktree, remove it now:
   `git worktree remove --force "$REVIEW_DIR"`. Never remove the user's checkout or a worktree
   that already existed.

If the review fails or posts nothing, say so in one line, remove the temporary worktree if there
is one, and move on — don't retry.

## Step 4 — Report

Report right after starting the 3a wait — don't hold the report until Claude's review runs. One
short line per reviewer: Codex comment posted, Copilot requested, Claude's review queued to run once
they've posted (up to 15 minutes) — or what failed for each. Say which checkout Claude's review will
read (current checkout, existing worktree, or a temporary one at the PR head).

When Claude's review finishes, add one line saying how many findings it posted and how many it
skipped as already raised, if it says.

When called from another skill, keep it to those lines so the caller can fold them into its own
report.

## Rules

- Only add reviewers. Don't approve, merge, change the PR's draft state, labels or description, or
  request review from any human.
- Never check out a branch in the user's current checkout. Only remove the worktree this run created.
- Only edit comments that Claude's review posted in this run. Never edit anyone else's comments, or
  the user's own from before the run.
- Dedupe by having Claude skip findings, never by hiding, resolving or editing Codex's or Copilot's
  comments.
