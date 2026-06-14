# Rolling three-tier changelog — protocol

The `.claude/changelog/` folder uses three tiers to keep history rich
without bloating the file Claude reads at session start.

## The three files

| File | Holds | Rolls over to |
|---|---|---|
| `daily.md` | Today's raw entries, newest on top | `weekly.md` when the calendar week rolls over |
| `weekly.md` | Compressed summary of the past 4-8 weeks | `changelog.md` when a calendar quarter rolls over |
| `changelog.md` | Long-term history, week-by-week or month-by-month | (nothing — keep it forever) |

## What goes where

### `daily.md` — raw, append-only

One line per logical change. Tag at the start.

**Tags:**

- `[CODE]` — theme code change
- `[BUILD]` — Vite / Composer / NPM build ran
- `[DEPLOY-STAGING]` — push or deploy to staging
- `[DEPLOY-PROD]` — promote to prod (backup ack acknowledged)
- `[DIRECT-PROD]` — edit made directly on production via SSH (high
  risk, not in Git)
- `[PULL-DB]` — production DB pulled to local
- `[PULL-UPLOADS]` — production uploads pulled to local
- `[DECISION]` — architectural choice worth recording
- `[LEARNED]` — non-obvious fact about this project
- `[CHORE]` — tooling / dep update / config tweak

Format:

```markdown
## YYYY-MM-DD

- HH:MM — [TAG] One-line summary. Target: {what}. Cause: {why if non-obvious}.
```

Newest day section on top. Newest entry within a day section on top.

### `weekly.md` — compressed past

Once a week (rolling), Claude (or you) compresses `daily.md` into a
weekly summary. The day-by-day raw entries become a single
multi-paragraph section per week.

Format:

```markdown
## Week of YYYY-MM-DD (DD–DD)

**Theme of the week:** {1-2 sentences}.

**Code changes:** {bullet list of the meaningful CODE entries}.

**Deploys:** N to staging, M to prod. Notable: {anything worth keeping}.

**Decisions / Learned:** {summarize}.
```

Detail-level lines that aren't important enough to keep forever
disappear at compression time. Things that MUST survive:

- `[DECISION]` entries — copy verbatim
- `[DIRECT-PROD]` entries — copy verbatim (audit trail)
- `[LEARNED]` entries — copy if they're durable; drop if they were
  superseded
- `[DEPLOY-PROD]` entries — list the dates + summaries, drop the
  per-deploy details

### `changelog.md` — long-term

Once a quarter, compress `weekly.md` into a per-month or per-quarter
narrative in `changelog.md`. By this point you should be telling
stories ("Q2 2026 — major redesign launched; new CPT for case studies;
moved to Tailwind v4"), not enumerating individual commits.

## Triggers

- **Roll daily → weekly:** when Monday rolls around and there are
  >2 weeks of entries in `daily.md`. Or when the user asks ("compress
  the changelog").
- **Roll weekly → changelog.md:** when a calendar quarter rolls over
  (April 1, July 1, October 1, January 1). Or when the user asks.

The rolls don't have to be automatic — Claude can offer to compress
when it sees the file getting unwieldy.

## When Claude writes to these files

`daily.md` gets a new entry at the end of any session that did
something durable. Quick rule: if the session would be worth telling
the next teammate about in one sentence, log it.

`weekly.md` and `changelog.md` get written only at rollover time, or
when the user explicitly asks ("compress this changelog").

## Cross-reference

- `.claude/CLAUDE.md` — project overview + decisions log
- `~/.claude/skills/norml-wp-developer/SKILL.md` — the write-back
  rules
