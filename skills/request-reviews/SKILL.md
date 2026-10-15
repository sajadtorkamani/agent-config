---
name: request-reviews
description: Get AI reviews on a GitHub PR from every reviewer I use — comments `@codex review` for Codex, requests Copilot as a reviewer, and, once those two have posted, runs Claude's `/code-review` with its comments prefixed `🤖 Claude (<model>):` (so they're clearly Claude's even though they post under my name), posts a "no major issues" comment when it finds nothing, and told to skip issues Codex or Copilot already raised. Use when the user runs /request-reviews [pr], asks to get reviews on a PR, or wants the AI reviewers re-run after pushing fixes. Also called by delegate-task.
allowed-tools: AskUserQuestion, Skill, Bash, Agent
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
To make it obvious they came from Claude, and which model reviewed, every comment this review
posts must start with the **prefix** `🤖 Claude (<model>): ` — emoji, the word Claude, the model
in brackets, a colon, a space. `<model>` is the name and version of the model you're running as (e.g.
`Opus 5.5`, `Sonnet 5.5`, `Fable 5.1`), e.g. `🤖 Claude (Opus 5.5): `. The review agent in 3c inherits your model,
so fill the prefix in yourself before handing it over.

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
        --jq "[.[] | select(.user.login == \"chatgpt-codex-connector[bot]\" and .created_at >= \"$since\"
                    and (.body | contains(\"codex-pull-request-review-summary\") | not))] | length")" != 0 ]
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
issues" and errors as comments rather than reviews. Its "Codex Review Summary" status card doesn't
count: Codex posts that the moment the review starts, while it still says "Running".
Run the loop with `bash` (e.g. inside `bash <<'EOF' ... EOF`), not the user's shell: zsh handles
word splitting differently, and an API error makes a check pass. The 15-minute cap means a reviewer that never
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

1. Record the time just before launching, for step 3: `date -u +%Y-%m-%dT%H:%M:%SZ`. Also
   record the commit being reviewed, for the "no issues" comment in step 3:
   `gh pr view <url> --json headRefOid -q .headRefOid`.
2. Launch the review through the **Agent tool** (`subagent_type: "general-purpose"`, description
   e.g. `Claude review of PR <number>`), not by invoking `code-review` directly. `code-review`
   runs as a forked agent that doesn't see anything you write before invoking it, and its args
   can't carry extra instructions (everything after the level and flags is read as the review
   target). An agent's prompt is the one place the rules are guaranteed to reach. Fill in this
   prompt:

   ```text
   Run the `code-review` skill (Skill tool, skill: code-review) with
   args: "high --comment <url>". Always pass the level "high" explicitly.

   Rules for the review, which take precedence over the skill's own defaults:
   - Start every comment you post on the PR with "<prefix>" (e.g. "🤖 Claude (Opus 5.5): ").
   - The PR's code is checked out at <review dir>. Read it from there, not from your current
     working directory: open files by their absolute paths under it, run git and other
     commands with `cd <review dir> &&` or `git -C <review dir>`, and pass the full PR URL to
     every `gh` command (e.g. `gh pr diff <url>`) so it can't resolve to another repo.
   - These unresolved comments are already on the PR (some may be the author's own notes
     rather than issues):
     <the 3b listing, one per line>
     Review the whole PR as normal, but don't post a finding with the same root cause as one
     of these, even if it's on a different line or worded differently. Only skip it when
     you're confident it's the same issue; if unsure, post it. A finding about the same code
     but a different defect is not a duplicate.

   When done, reply with how many findings you posted, and list any you skipped as already
   raised (file:line and which existing comment).
   ```

   Leave out the "already on the PR" rule when the 3b listing is empty. Always pass the level
   explicitly, as above — without one, the review reuses whatever level the user last typed, so
   reviews would get inconsistent depth.
3. The agent runs in the background and its result arrives later as a task notification. Don't
   wait for it. When the notification arrives, make sure every comment it posted is prefixed
   anyway — the prompt asks for it, but this check is the guarantee. Fetch the user's comments on the PR created since the
   recorded time — inline review comments, review bodies, and top-level comments:

   ```bash
   ME="$(gh api user -q .login)"
   gh api "repos/<owner>/<repo>/pulls/<number>/comments" --paginate \
     --jq ".[] | select(.user.login == \"$ME\" and .created_at >= \"<since>\") | {id, body}"
   gh api "repos/<owner>/<repo>/pulls/<number>/reviews" --paginate \
     --jq ".[] | select(.user.login == \"$ME\" and .submitted_at >= \"<since>\" and .body != \"\") | {id, body}"
   gh api "repos/<owner>/<repo>/issues/<number>/comments" --paginate \
     --jq ".[] | select(.user.login == \"$ME\" and .created_at >= \"<since>\") | {id, body}"
   ```

   For each one whose body doesn't already start with the prefix, prepend it and save it back — `PATCH repos/<owner>/<repo>/pulls/comments/<id>` for inline comments,
   `PUT repos/<owner>/<repo>/pulls/<number>/reviews/<id>` for review bodies,
   `PATCH repos/<owner>/<repo>/issues/comments/<id>` for top-level comments, each with
   `-f body=<new body>`. Leave any `@codex review` trigger comment alone — editing it can stop
   Codex picking it up. Then tell the user in one line how many findings Claude posted and that
   they're prefixed.

   If the review completed but posted **no findings**, say so on the PR the way Codex does, with a
   top-level comment (`gh pr comment <url> --body-file -`), using the commit recorded in step 1
   (first 10 characters):

   ```markdown
   🤖 Claude (<model>) Review: Didn't find any major issues.

   **Reviewed commit:** `<short sha>`
   ```

   If it skipped findings as already raised, write "Didn't find any major issues beyond those
   already raised." instead. Only post this when the review actually finished — not when it
   failed.
4. If Step 0b created a temporary worktree, remove it now:
   `git worktree remove --force "$REVIEW_DIR"`. Never remove the user's checkout or a worktree
   that already existed.

If the review fails, say so in one line (and don't post the "no issues" comment), remove the
temporary worktree if there is one, and move on — don't retry.

## Step 4 — Report

Report right after starting the 3a wait — don't hold the report until Claude's review runs. One
short line per reviewer: Codex comment posted, Copilot requested, Claude's review queued to run once
they've posted (up to 15 minutes) — or what failed for each. Say which checkout Claude's review will
read (current checkout, existing worktree, or a temporary one at the PR head).

When Claude's review finishes, add one line saying how many findings it posted and how many it
skipped as already raised, if it says — or that it found none and posted the "no issues" comment.

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
