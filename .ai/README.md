# Portable AI Assets

This folder is the tracked, vendor-neutral source for shared agent assets.

## What Belongs Here

- reusable skills in `.ai/skills/<name>/SKILL.md`
- optional tracked agent definitions or templates in `.ai/agents/`
- docs that explain how the repo expects agents to behave

## Local Install Targets

Use gitignored client-specific folders as install targets when you need them:

- `.agents/skills/`
- optional `.claude/`
- optional `.codex/`
- optional `.copilot/`

Typical pattern:

```bash
mkdir -p .agents/skills
ln -sfn ../../.ai/skills/bootstrap-current-checkout .agents/skills/bootstrap-current-checkout
ln -sfn ../../.ai/skills/worktree-lifecycle .agents/skills/worktree-lifecycle
```

Each tracked skill should follow the Agent Skills layout so Boost and OpenCode can both consume it:

```text
.ai/skills/<name>/SKILL.md
```

The tracked files remain canonical. Local targets are just discovery surfaces for a specific tool.

For local OpenCode config, copy `opencode.jsonc.example` to ignored `opencode.jsonc` and keep machine-specific reminders in `AGENTS.local.md`.

This repo is prepared for Laravel Boost later, but does not install it by default. If a team opts in later, Boost can publish or sync local client files from these tracked sources, but that should stay a deliberate follow-up step.
