# Decision Review

## Decision

- `Decision:` Require the backend template to keep OpenAI Agents SDK behavior on the server and support broad SDK-native customization such as model and instructions, tools, handoffs, guardrails, sessions, MCP, and related configuration through a maintainable generic architecture instead of narrow hardcoded flows.
- `Scope Reviewed:` Backend requirements and architecture guardrails in [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md):36, [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md):38, [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md):40, [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md):48, [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md):54, [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md):61, [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md):111, and [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md):125. No backend implementation files are present in the repository yet.

## Evidence Reviewed

- `Code:` None; no backend implementation files are present in the repository yet.
- `Tests/Specs/Diffs:` [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md):16, [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md):18, [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md):38, [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md):40, [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md):48, [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md):49, [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md):50, [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md):54, [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md):61, [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md):111, [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md):115, [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md):125
- `Docs:` https://openai.github.io/openai-agents-python/quickstart/, https://openai.github.io/openai-agents-python/config/, https://openai.github.io/openai-agents-python/sessions/, https://openai.github.io/openai-agents-python/handoffs/, https://openai.github.io/openai-agents-python/guardrails/, https://openai.github.io/openai-agents-python/mcp/

## Lens Check

- `Simplicity:` No material issue in the decision itself; for a reusable template, staying aligned with first-class Agents SDK concepts is simpler than adding separate narrow backend flows for each capability.
- `Structure:` No material issue; the decision keeps ownership of agent behavior in the backend and preserves the iOS client as a thin chat surface.
- `Operability:` No material issue; leaning on SDK-native sessions, guardrails, and MCP is operationally safer than inventing parallel control paths before there is a demonstrated need.
- `Scale:` No material issue; a backend shaped around SDK-native composition should age better than duplicated hardcoded paths as more agent features are added.

## Findings

No material findings.

## Recommended Fix Actions

No fix action recommended: this decision is justified by the template's stated product goal, and the same spec already constrains execution against speculative abstraction by requiring the backend to stay minimal, legible, and easy to extend.

## Sources

- https://openai.github.io/openai-agents-python/quickstart/
- https://openai.github.io/openai-agents-python/config/
- https://openai.github.io/openai-agents-python/sessions/
- https://openai.github.io/openai-agents-python/handoffs/
- https://openai.github.io/openai-agents-python/guardrails/
- https://openai.github.io/openai-agents-python/mcp/
