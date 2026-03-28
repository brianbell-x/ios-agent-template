# Decision Review

## Decision

- `Decision:` Require the iOS frontend to evoke the ChatGPT iOS app's layout and interaction model while avoiding copied branding, proprietary assets, or exact visual details, and while keeping the UI limited to a generic chat surface. The scope reviewed is this written product decision, because no frontend implementation exists in the repository yet.
- `Scope Reviewed:` [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L5C1), [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L15C1), [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L24C1), [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L52C1), [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L117C1)

## Evidence Reviewed

- `Code:` None; the repository contains no iOS or frontend implementation files.
- `Tests/Specs/Diffs:` [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L5C1), [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L15C1), [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L24C1), [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L54C1), [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L108C1), [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L121C1)
- `Docs:` None

## Lens Check

- `Simplicity:` Mostly sound: the decision intentionally narrows the frontend to a chat surface and explicitly rejects feature bloat, but the "feel like ChatGPT" requirement is subjective enough to create some avoidable interpretation work.
- `Structure:` Mostly sound: ownership stays clear because the frontend is defined as a generic chat client, though the resemblance boundary is not concrete enough for multiple contributors to apply consistently.
- `Operability:` No material operational issue is introduced by the decision itself; the main downside is review churn from subjective UI judgment rather than runtime fragility.
- `Scale:` No material scale issue; a narrow chat-first UI lowers long-term surface area, testing burden, and coordination cost.

## Findings

### [low] [structure] Subjective resemblance target leaves design acceptance implicit

- `Evidence:` [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L25C1) requires the app to feel visually similar to ChatGPT in layout, tone, spacing, and interaction; [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L26C1) forbids exact visual copying; [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L27C1), [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L33C1), and [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L34C1) narrow the feature scope; [AGENTS.md](/C:/dev/ios-agent-template/AGENTS.md#L82C1) tells implementers to resolve ambiguity autonomously.
- `Problem:` The spec gives a clear product direction but not a concrete acceptance boundary for what counts as "similar feel" versus "too close," so each contributor has to infer the design contract.
- `Why It Matters:` This is unlikely to cause production failures, but it can create review churn, inconsistent UI choices, and rework in a template repository that is supposed to be easy for another engineer to pick up and extend.
- `Better Direction:` Keep the ChatGPT-like direction, but add a short design contract with explicit allowed primitives and explicit prohibitions so the intended feel is reproducible without imitation.

## Recommended Fix Actions

1. Add a concise frontend design brief alongside `AGENTS.md` that translates the desired feel into a few concrete primitives, such as transcript layout, composer placement, motion restraint, color tone, and spacing rules.
2. Add a short "do not copy" checklist covering logos, exact iconography, branded copy, and any proprietary visual flourishes, so contributors do not have to infer that boundary from one sentence.
3. Keep the narrow frontend scope unchanged; it is the part of this decision that most clearly reduces unnecessary complexity.

## Sources

None
