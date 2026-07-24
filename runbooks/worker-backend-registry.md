# Worker Backend Registry


Engine choice is the `(runner_kind, runner_provider)` pair resolved through
the `WorkerRunnerProvider` registry in
`bus-integration-worker/pkg/workersintegration/runner_provider.go`; providers
`codex-direct`, `codex-appserver`, and `bus-agent-runtime` coexist today. For
a Claude-backed provider design (Agent SDK vs persistent stream-json stdio vs
`ModelProvider`, Codex concept mapping, auth policy), read the research note
`docs/docs/research/claude-worker-backend.md` before re-researching.
