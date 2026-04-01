# PLAN.md

- [x] Refresh the superproject agent container workflow so `scripts/start-shell.sh` and `scripts/start-agent.sh` provide a reproducible Go + Codex development environment with current toolchain packages, wrapper coverage, a real container e2e check, and any needed usage/doc updates in the same change set.
- [x] Refine the default agent-container interactive shell prompt so `scripts/start-shell.sh` opens with a stable BusDK-specific prompt instead of the container fallback identity prompt, with self-test coverage in the same change set.
