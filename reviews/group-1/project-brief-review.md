# Decision Review

## Decision

- `Decision:` Use the rewritten project brief in [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L1C1) as the governing decision for this repository: build a reusable starter template rather than a demo, keep the iOS client narrowly chat-focused with a ChatGPT-like feel but no brand cloning, make the backend the source of truth for broadly configurable OpenAI Agents SDK behavior, and execute autonomously from an almost empty repository while keeping the code lean, documented, and milestone-driven.
- `Scope Reviewed:` [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L5C1), [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L11C1), [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L24C1), [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L38C1), [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L54C1), [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L80C1), [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L98C1), [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L108C1), [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L121C1)

## Evidence Reviewed

- `Code:` None; the repository does not yet contain implementation modules, only [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L1C1) and the `reviews/` folder.
- `Tests/Specs/Diffs:` [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L5C1), [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L11C1), [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L24C1), [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L38C1), [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L54C1), [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L80C1), [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L98C1), [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L108C1), [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L121C1)
- `Docs:` https://openai.github.io/openai-agents-python/, https://openai.github.io/openai-agents-python/config/, https://openai.github.io/openai-agents-python/mcp/

## Lens Check

- `Simplicity:` Mostly sound, but the backend requirement to support the "full spirit" of SDK customization plus any other important supported configuration is open-ended enough to encourage a mirror-the-SDK abstraction layer in a starter template.
- `Structure:` The client/backend split is clean and the chat-only frontend is a good boundary, but the ChatGPT-like frontend brief still leaves some acceptance criteria implicit.
- `Operability:` The workflow introduces real execution risk because it requires milestone commits and commit reviews during autonomous delivery without bootstrapping git or defining a fallback when the repo starts almost empty.
- `Scale:` No material runtime scale issue is introduced by the brief itself; the narrow frontend scope and explicit separation of concerns are scale-friendly, though an overly broad backend configurability layer would create maintenance scale cost.

## Findings

### [medium] [simplicity] Open-ended SDK configurability target invites speculative abstraction

- `Evidence:` [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L38C1) through [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L50C1) require the backend to be the source of truth for agent behavior, support the "full spirit" of Agents SDK customization, prefer generic pass-through, and make room for any other important supported SDK configuration. [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L60C1) through [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L61C1) and [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L121C1) through [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L125C1) also warn against clever abstractions and speculative future work. The official SDK overview says the SDK is built around a small set of primitives with "very few abstractions," while the docs also show additional configurable surfaces such as tracing, logging, API selection, and MCP transport options that extend beyond the brief's explicit list.
- `Problem:` The brief asks for broad backend extensibility but does not define where the template should stop. In practice that nudges implementers toward a custom configuration layer or proxy API that tries to anticipate the evolving SDK surface.
- `Why It Matters:` That is unnecessary moving machinery for a starter template. It creates drift risk as the SDK adds or changes options, increases backend glue code, and makes the template harder for the next engineer to understand than a thinner SDK-native seam would be.
- `Better Direction:` Keep the backend native to the SDK's documented primitives and explicitly support the listed extension points, but change the brief so unimplemented SDK options are documented extension seams rather than part of an implicit parity promise.

### [medium] [operability] Milestone-commit workflow assumes repo state that the brief does not establish

- `Evidence:` [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L7C1) says the repository may start nearly empty, [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L80C1) through [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L85C1) require autonomous execution, and [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L98C1) through [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L101C1) require milestone commits plus commit reviews. Repository inspection showed `C:\dev\ios-agent-template` currently contains only [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L1C1) and `reviews/`, with no `.git` directory, and `git rev-parse --is-inside-work-tree` fails.
- `Problem:` The workflow makes commit history part of the expected delivery path, but the brief does not say whether initializing git is mandatory, assumed, or optional, and it provides no fallback when that assumption is false.
- `Why It Matters:` An autonomous implementer cannot satisfy the workflow deterministically in a fresh or unpacked directory. That leads to either blocked execution or silent noncompliance with a stated project rule, which weakens traceability and review discipline exactly where the brief says they matter.
- `Better Direction:` Add an explicit bootstrap precondition such as "initialize git before milestone work begins," or define a fallback checkpoint mechanism in repo-local docs when version control is unavailable.

### [low] [structure] ChatGPT-like frontend direction is still too implicit for repeatable review

- `Evidence:` [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L25C1) through [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L34C1) require the app to feel similar to the ChatGPT iOS app while avoiding copied branding or exact visual details, and [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L80C1) through [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L82C1) direct contributors to resolve ambiguity autonomously.
- `Problem:` The brief gives a strong product direction, but it does not translate that direction into concrete acceptance rules for layout, motion, spacing, or copy boundaries.
- `Why It Matters:` This is unlikely to create runtime problems, but it does create review churn and inconsistent UI choices in a template that is supposed to be easy for another engineer to extend without reverse engineering intent.
- `Better Direction:` Keep the narrow chat-only product shape, but add a small design contract that names the allowed UX primitives and the specific categories of branded details that must not be copied.

## Recommended Fix Actions

1. Narrow the backend extensibility requirement to an SDK-native seam: explicitly require support for `Agent` instructions/model/tools/handoffs/guardrails/sessions/MCP and treat any further SDK surface as documented extension points rather than default parity work.
2. Add one workflow bootstrap rule in [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L96C1): initialize git before milestone work starts, or record milestone checkpoints in repo-local docs until git is available.
3. Add a concise frontend design brief that converts the "ChatGPT-like" goal into a few reproducible rules for transcript layout, composer placement, spacing, motion restraint, and a short do-not-copy checklist.

## Sources

- https://openai.github.io/openai-agents-python/
- https://openai.github.io/openai-agents-python/config/
- https://openai.github.io/openai-agents-python/mcp/
