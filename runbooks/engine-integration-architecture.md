# Engine-Integration Architecture (Accepted Decision)


Engine-integration architecture (operator, 2026-07-06): each AI engine gets
its own `bus-integration-<engine>` module that OWNS that engine's main App
Server / agent process instance and exposes it to the rest of Bus through the
Bus Events API under a matching `bus.<engine>.*` event namespace
(`bus-integration-codex` -> `bus.codex.*`, `bus-integration-claude` ->
`bus.claude.*`). Naming must stay aligned module <-> namespace. No one-shot
engine turns anywhere in the codebase: sessions are persistent and steerable.
Other modules (workers, chat, LLM API providers) integrate with engines only
through those events, never by spawning or dialing engine processes directly.
The current `bus-integration-codex` `bus.llm.*` one-shot turn path and the
direct per-worker `codex app-server` spawning in `bus-integration-worker`
predate this rule and are refactoring targets, not precedent.

