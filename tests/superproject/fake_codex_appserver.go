package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"strings"
)

type frame struct {
	ID     *int64          `json:"id,omitempty"`
	Method string          `json:"method,omitempty"`
	Params json.RawMessage `json:"params,omitempty"`
	Result any             `json:"result,omitempty"`
	Error  any             `json:"error,omitempty"`
}

func main() {
	scanner := bufio.NewScanner(os.Stdin)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		var req frame
		if err := json.Unmarshal([]byte(line), &req); err != nil {
			continue
		}
		switch req.Method {
		case "initialize":
			respond(req.ID, map[string]any{"serverInfo": map[string]any{"name": "fake-codex-appserver"}})
		case "initialized":
		case "thread/start":
			respond(req.ID, map[string]any{"threadId": "thread-smoke"})
		case "turn/start":
			respond(req.ID, map[string]any{"turnId": "turn-smoke"})
			notify("turn/started", map[string]any{"turnId": "turn-smoke", "threadId": "thread-smoke"})
			text := inputText(req.Params)
			if strings.Contains(text, "APP_SERVER_SMOKE_DONE") || strings.Contains(text, "BENCH_DONE") {
				notify("codex/event/agent_message_delta", map[string]any{"msg": map[string]any{"delta": text}})
				notify("turn/completed", map[string]any{"turnId": "turn-smoke", "threadId": "thread-smoke"})
			}
		case "turn/steer":
			respond(req.ID, map[string]any{})
			text := inputText(req.Params)
			notify("codex/event/agent_message_delta", map[string]any{"msg": map[string]any{"delta": text}})
			notify("turn/completed", map[string]any{"turnId": "turn-smoke", "threadId": "thread-smoke"})
		default:
			respond(req.ID, map[string]any{})
		}
	}
}

func respond(id *int64, result any) {
	if id == nil {
		return
	}
	write(frame{ID: id, Result: result})
}

func notify(method string, params any) {
	raw, _ := json.Marshal(params)
	write(frame{Method: method, Params: raw})
}

func write(msg frame) {
	raw, _ := json.Marshal(msg)
	fmt.Println(string(raw))
}

func inputText(raw json.RawMessage) string {
	var payload struct {
		Input []struct {
			Text string `json:"text"`
		} `json:"input"`
	}
	_ = json.Unmarshal(raw, &payload)
	if len(payload.Input) == 0 {
		return "missing-steer-text"
	}
	text := strings.TrimSpace(payload.Input[0].Text)
	if text == "" {
		return "empty-steer-text"
	}
	return text
}
