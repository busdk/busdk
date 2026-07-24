# Repository Visibility And Secrets


1. Public/open-source repos: `./` (superproject), `./bus`, `./docs`,
   `./busdk.com`.
2. Private/commercial-customer repos: every `./bus-*` module unless that
   module's own repository documents otherwise.
3. In public repos, do not introduce in-process coupling to private module
   internals; use stable CLI/library/API boundaries only.
4. This public superproject and its public docs/examples must never contain real
   SMTP, database, JWT, API, AI provider, webhook, signing, password, private
   key, DSN-with-password, or customer secrets.
5. Do not accept secret values as command-line arguments in BusDK tools or
   services. Secrets must come from environment variables, user config secret
   files, deployment secret files, OS credential storage, or standard input
   where explicitly designed.
6. Treat committed `AGENTS.md`, docs, and examples as public unless they are
   explicitly inside a private repository. Logs, memos, and notes are internal
   operator records; never write secrets into them.
7. Never print broad `.env` contents. Query only exact non-secret keys or report
   key presence with values redacted.
8. Never auto-write JWTs, API tokens, refresh tokens, or auth-session files
   under repository-local `.bus/` paths or any other working-tree-relative
   default. Use the unified user config root, explicit operator-supplied paths,
   environment variables, or OS credential storage.
9. For multi-remote worker credential design, keep root metadata non-secret and
   read `skills/bus-dev-task-worker-ops/SKILL.md`.

