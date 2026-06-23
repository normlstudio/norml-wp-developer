# CI/CD — Reference Folder

Everything the skill knows about getting code from local to production safely.

## Files

| File | Read it when |
|---|---|
| `patterns.md` | Picking or operating a deploy pattern. The three patterns (`full-pipeline`, `prod-direct-with-git`, `prod-direct-no-ci`), their GitHub Actions shape, and the per-project `.claude/ci-cd.md` contract. |
| `database-strategies.md` | Deciding how content / the database moves (or doesn't) between environments. Four strategies, the `wp` commands, and the hard rules that stop you clobbering live data. |
| `backup-strategies.md` | Setting up or verifying backups before a production write. Four provider types, restore runbooks, and how each maps to the backup-acknowledgement tiers (`host-automatic` / `manual-before-deploy` / `none-warned`). |

## How they fit together

```
patterns.md          →  picks the deploy SHAPE for a project (staging or not, CI or not)
   ├── database-strategies.md  →  how content / DB is handled under that pattern
   └── backup-strategies.md    →  what backup must exist before any production write
```

A project's choices from all three are recorded in its own
`{theme_root}/.claude/ci-cd.md` (scaffolded from `templates/ci-cd.template.md`),
which every deploy reads first.

## The non-negotiable

This skill never makes backups for you, and every production write gates on
the backup-acknowledgement prompt. The pattern and database strategy decide
*how* you deploy; the backup strategy decides whether you're *allowed* to —
both must clear. See `backup-strategies.md` and `../safety-rules.md`.
