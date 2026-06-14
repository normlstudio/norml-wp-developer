# Install norml-wp-developer

One-time install of the skill itself. Then one-time setup **per project**
(~30 minutes per project — see `onboarding.md`).

## Prerequisites

- **macOS** 12+ or **Windows** 10+ (with WSL recommended on Windows)
- **Claude Code** installed and signed in
  → https://claude.com/claude-code
- **Git** installed and configured (`git config user.name`, `user.email`)
- **A local WordPress environment.** Default: WP Local from Flywheel /
  WP Engine (https://localwp.com). Alternates the skill recognizes:
  DDEV, Lando, Local Lightning, Valet+, MAMP. At least one local WP
  install must be running before you finish project onboarding.
- **SSH access to your production WordPress server** (host, port,
  username, key — or willingness to generate one and add it to the
  server). For managed hosts: this is usually under "SSH Keys" in the
  control panel (Kinsta, WP Engine, SiteGround, etc.).
- **A remote Git repo.** GitHub by default. Bitbucket and GitLab also
  supported. You need:
  - An empty repo at the remote, OR
  - Push permission to an existing repo
- **WP-CLI on the production server.** Most managed hosts have it
  pre-installed. If not, see https://wp-cli.org/#installing or ask
  your host.

> **No backups are provided by this skill.** It assumes the production
> host has automatic backups on, or that you'll take manual backups
> before destructive operations. The deploy commands will refuse to
> run without an explicit "I have a backup" acknowledgement.

## Step 1 — Extract the package

If you received this as a zip, unzip it anywhere convenient (Desktop or
Downloads).

## Step 2 — Copy the skill into Claude's skill folder

The skill needs to live in `~/.claude/skills/norml-wp-developer/` so
Claude Code picks it up automatically.

### macOS

```bash
mkdir -p ~/.claude/skills
cp -R "/path/to/extracted/norml-wp-developer/.claude/skills/norml-wp-developer" ~/.claude/skills/
```

### Windows

```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude\skills" | Out-Null
Copy-Item -Recurse -Force "C:\path\to\extracted\norml-wp-developer\.claude\skills\norml-wp-developer" "$env:USERPROFILE\.claude\skills\"
```

## Step 3 — Make the scripts executable (macOS only)

```bash
chmod +x ~/.claude/skills/norml-wp-developer/scripts/*.sh
```

Windows skips this step.

## Step 4 — Verify Claude sees the skill

Open Claude Code (in any folder). Type:

> *"List my available skills."*

You should see `norml-wp-developer`. If not, restart Claude Code.

## Step 5 — Run first-time setup for your first project

In Claude Code, navigate to your project folder (`cd ~/Local Sites/{site}/app/public/wp-content/themes/{theme}` is typical for WP Local users) and say:

> *"Set up this project for norml-wp-developer."*

Or *"init this WP project."*

Claude walks you through onboarding in chat — collecting details,
**popping native OS dialogs for SSH passphrases**, scaffolding
`.claude/` inside your theme repo, optionally pulling the production
database to local. The full step-by-step is in
`~/.claude/skills/norml-wp-developer/onboarding.md`.

You can also run setup manually:

**macOS:**
```bash
bash ~/.claude/skills/norml-wp-developer/scripts/setup-macos.sh
```

**Windows:**
```powershell
& "$env:USERPROFILE\.claude\skills\norml-wp-developer\scripts\setup-windows.ps1"
```

## Step 6 — Start building

Once setup finishes:

- *"Add a hero block to this theme."*
- *"Build a CPT archive for case studies."*
- *"What plugins are active on production? On staging?"*
- *"Pull the production database to my local."*
- *"Ship this branch to staging."*
- *"Promote staging to production."* — gated by the backup prompt.
- *"Show me the recent changelog for this project."*

## Repeat Step 5 for every project

Each project gets its own `~/.config/norml-wp-developer/projects/{slug}.json`
and its own `.claude/` folder in its theme repo. You can manage many
projects from one machine — they share the SSH agent but not the
config.

## Troubleshooting

| Problem | Fix |
|---|---|
| Claude can't see the skill | Restart Claude Code. Confirm the folder is at `~/.claude/skills/norml-wp-developer/`. |
| `Permission denied (publickey)` during setup | Your SSH public key isn't on the production server. Re-run setup; the script prints the public key for you to paste into your host's control panel. |
| `wp: command not found` on the remote | WP-CLI isn't on the server. Ask your host or install per https://wp-cli.org/#installing. |
| `Composer detected ... platform_check.php` | Server PHP version is below what the theme's `composer.json` requires. Either bump server PHP in the hosting panel or lower the theme's `require.php` floor (developer task). |
| Setup script won't run on Windows | Run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` in PowerShell first. |
| WP Local site not detected | Make sure the site is **running** (green status in WP Local). The detection script looks for an active mySQL process matching `/Local Sites/`. |
| `git push` rejected (no remote auth) | Configure GitHub auth via SSH key or PAT. The setup script offers to use GitHub CLI (`gh auth login`) which is the easiest path. |

If you get stuck, contact whoever sent you this package.

## What's NOT installed

For full transparency, the skill writes only these things on your
machine:

- The skill folder at `~/.claude/skills/norml-wp-developer/`
- Per-project config at `~/.config/norml-wp-developer/projects/{slug}.json`
  (no secrets)
- Per-project SSH config alias in `~/.ssh/config` (host alias only,
  the key file lives wherever you already keep them)
- One entry per project in macOS Keychain / Windows Credential Manager
  for the SSH passphrase (if any)
- A `.claude/` folder INSIDE each theme repo it initializes (in git;
  travels with the code)
- A first commit on the theme repo if it wasn't already a git repo

It does **not** install any system services, daemons, PowerShell
modules, Python packages, or Node packages on your machine. It does
**not** modify your WordPress install on the server beyond `rsync`ing
theme files and (optionally) running WP-CLI cache flushes after deploy.

It does **not** make backups for you.

## Updating later

When a new version of the skill is sent to you:

1. Re-extract the package.
2. Re-run Step 2 (the copy command). It overwrites the old skill folder.
3. Your config in `~/.config/norml-wp-developer/` is **not** touched —
   you keep your project list, SSH aliases, and per-project knowledge.
4. The `.claude/` folder inside each theme repo is **not** touched —
   it lives in git, travels with the code.
