# Install Norml WordPress Copilot Advanced

Public product name: **Norml WordPress Copilot Advanced**. Installed skill:
`norml-wp-developer`.

Repository: `normlstudio/norml-wordpress-copilot-advanced`. The installed slug
remains `norml-wp-developer` for compatibility with existing installations and
project state.

## CLI only

Install this skill in Claude Code, Codex, or Gemini CLI. It requires local
filesystem access, Git, GitHub, SSH, and remote WP-CLI. Do not upload it to Claude
Desktop / Cowork; use Norml WordPress Copilot (`norml-wp-manager`) there.

## Install

### Claude Code

```bash
npx skills@latest add normlstudio/norml-wordpress-copilot-advanced --skill=norml-wp-developer -g -a claude-code
```

### Codex

```bash
npx skills@latest add normlstudio/norml-wordpress-copilot-advanced --skill=norml-wp-developer -g -a codex
```

### Gemini CLI

```bash
npx skills@latest add normlstudio/norml-wordpress-copilot-advanced --skill=norml-wp-developer -g -a gemini-cli
```

Restart the runtime if it does not discover the skill immediately.

## Prepare the project

1. Start the local WordPress environment.
2. Open a terminal in the theme root—the folder containing `style.css`.
3. Confirm Git is installed and the theme has or can create a GitHub repository.
4. Confirm you can add an SSH public key to the production hosting account.
5. Confirm the production WordPress root can run `wp --info` over SSH.

## Run onboarding

Say:

> Set up this project for Norml WordPress Copilot Advanced.

The skill follows [`onboarding.md`](onboarding.md). It does not finish until it has:

- connected and read-verified the GitHub origin;
- connected production SSH;
- verified remote WP-CLI in the exact WordPress root;
- created the theme-local `.claude/` project layer;
- generated `.claude/capabilities.md`, `.claude/architecture.md`, and the detailed
  architecture snapshot.

## Verify

After onboarding, ask:

> Explain this project and show me the boundaries in capabilities.md.

Then run:

```bash
git status --short
git remote -v
```

The generated `.claude/` files should be reviewed and committed with the theme.
Connection metadata and secrets remain outside the repository.

## Credential rules

- GitHub authentication uses GitHub CLI or SSH/OS-managed credentials.
- Hosting authentication uses an SSH key and ssh-agent.
- Never put tokens, passphrases, private keys, database credentials, or hosting
  passwords in chat, project config, `.claude/`, commits, or workflow files.
- GitHub Actions secrets are configured in GitHub, not written into the repo.

## Updating

Re-run the same install command to obtain a newer package through the Skills CLI.
Skill updates do not overwrite a project's theme-local `.claude/` layer. Run the
architecture scanner when the new version changes the generated documentation
contract.
