# norml-wp-developer

**Build WordPress themes locally and ship them to production through Claude Code —
Git-backed, SSH-deployed, no credentials in chat.**

A [Claude Code](https://claude.com/claude-code) skill for **WordPress developers**.
It turns the developer-friendly flow — work locally, commit, push, watch CI/CD
deploy to staging, smoke test, promote to prod — into a ~30-minute-per-project
setup and a basically chat-driven everyday workflow.

> Just need to edit content on a live site (no code)? That's the companion,
> [`norml-wp-manager`](https://github.com/Norml-Studio/norml-wp-manager). A
> developer and a content owner can each install the right tool.

## What you can do

| When you want to… | Say something like… |
|---|---|
| Set up a new project | *"Set up this WordPress project."* (runs onboarding) |
| Add an ACF block | *"Add a hero block with title + subtitle + CTA fields."* |
| Build a CPT | *"Build a case-study CPT with an archive page."* |
| Deploy to staging | *"Ship this to staging."* |
| Promote to production | *"Promote staging to production."* (backup prompt fires) |
| Hot-fix on production | *"Edit footer.php directly on production to fix the year."* (flagged `[DIRECT-PROD]`) |
| Pull production DB | *"Pull production database to my local."* |
| See the changelog | *"What's in the recent changelog for this project?"* |

After setup, each project carries its own committed `.claude/` folder — so the
next session (you, a teammate, or Claude) starts with full context: the CI/CD
pattern in play, the conventions to follow (Sage vs inherited theme), the
recent changelog.

> ⚠️ **This skill does not make backups.** Deploy commands refuse to run without
> an explicit "I have a backup" acknowledgement. It assumes the production host
> has automatic backups on, or that you take manual ones before destructive ops.

## Requirements

- **Claude Code** on macOS 12+ or Windows 10+ (WSL recommended on Windows)
- **Git**, configured (`git config user.name` / `user.email`)
- **A local WordPress environment** — [WP Local](https://localwp.com) by default
  (DDEV, Lando, Valet+, MAMP also recognized)
- **SSH access** to your production WordPress server, with **WP-CLI** available there
- **A remote Git repo** (GitHub by default; Bitbucket / GitLab supported)

## Install

```bash
git clone https://github.com/Norml-Studio/norml-wp-developer.git
mkdir -p ~/.claude/skills
cp -R norml-wp-developer/.claude/skills/norml-wp-developer ~/.claude/skills/
chmod +x ~/.claude/skills/norml-wp-developer/scripts/*.sh   # macOS only
```

Then, from your theme folder in Claude Code: **"Set up this project for
norml-wp-developer."** Claude collects details, pops native OS dialogs for SSH
passphrases, scaffolds `.claude/` inside your theme repo, and optionally pulls
the production database to local.

Full step-by-step (including Windows): **[`INSTALL.md`](.claude/skills/norml-wp-developer/INSTALL.md)** (or the visual [`install.html`](.claude/skills/norml-wp-developer/install.html)).

## How your credentials are handled

- **SSH passphrases** are stored in **macOS Keychain** / **Windows Credential
  Manager**, one entry per project. Claude never sees them.
- Per-project connection config lives in `~/.config/norml-wp-developer/projects/{slug}.json` — **no secrets in the file**.
- Each project's committed `.claude/` folder holds conventions + changelog, and
  travels with the code.

## Documentation

- **[Guide](.claude/skills/norml-wp-developer/readme.md)** — what it is and how to use it. Visual one-pager: [`readme.html`](.claude/skills/norml-wp-developer/readme.html)
- **[Install guide](.claude/skills/norml-wp-developer/INSTALL.md)** — full setup, troubleshooting, "what's NOT installed". Visual: [`install.html`](.claude/skills/norml-wp-developer/install.html)
- **[Changelog](.claude/skills/norml-wp-developer/changelog.md)** — skill version history (currently v1.1.0)

## License

[MIT](LICENSE) © Norml Studio
