# Decision Review

## Decision

- `Decision:` Build the repository as a reusable starter template instead of a one-off demo, keep the iOS app as a narrow chat-only client, and keep agent behavior owned by the backend as described in `AGENTS.md`.
- `Scope Reviewed:` `AGENTS.md` only, specifically the product definition, frontend scope, backend scope, architecture expectations, definition of done, and non-goals; no iOS, backend, schema, or test modules exist in the repository yet.

## Evidence Reviewed

- `Code:` None
- `Tests/Specs/Diffs:` `AGENTS.md:11-18`, `AGENTS.md:27-50`, `AGENTS.md:54-67`, `AGENTS.md:104-125`
- `Docs:` None

## Lens Check

- `Simplicity:` The chat-only client and backend-owned agent behavior simplify the product, but the requirement to support the full spirit of SDK customization creates pressure toward an unnecessarily generic backend surface.
- `Structure:` Client and backend ownership are directionally clean, but the decision does not yet draw a crisp line between the template's stable API contract and backend-internal agent customization.
- `Operability:` Centralizing agent behavior on the backend is the safer operational choice, and no separate material operability issue is evident in the decision itself.
- `Scale:` A thin client and backend mediation are scale-friendly at this level, and no material scale issue is evident in the decision itself.

## Findings

### [medium] [simplicity] Broad customization goal can turn the template into an SDK pass-through

- `Evidence:` `AGENTS.md:38-50` requires the backend to support the full spirit of Agents SDK customization and prefers generic pass-through, while `AGENTS.md:61` and `AGENTS.md:125` also prohibit premature generalization and speculative abstractions.
- `Problem:` Those requirements pull in opposite directions. Without a sharper boundary, implementers are incentivized to mirror SDK options into template config or API shapes so the template can claim broad customization support.
- `Why It Matters:` That broadens the backend surface, couples the template to SDK churn, and pushes coordination onto future callers about which options belong in the template contract versus backend-local agent code.
- `Better Direction:` Keep the template contract narrow: chat or session input, streamed agent output, and backend-selected agent wiring. Treat model choice, tools, handoffs, guardrails, MCP, and similar SDK features as backend extension points unless a specific capability truly must cross the API boundary.

## Recommended Fix Actions

1. Replace the current "generic pass-through" expectation with an explicit backend contract that stays chat-shaped and stable even as agent internals change.
2. Document which customization points are backend-internal extension hooks versus supported template API inputs before implementation starts.

## Sources

None
