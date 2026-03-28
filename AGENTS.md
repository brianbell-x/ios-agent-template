# iOS Chat Agent Template

## Objective

Build a production-ready template for an iOS app that provides a clean ChatGPT-like chat experience on the frontend and uses the OpenAI Agents SDK on the backend.

This repository may start nearly empty. Create whatever project structure, app code, backend code, configuration, scripts, and documentation are required to finish the template end to end.
If the repository is not already a git repository, initialize it before milestone commits begin.

## Product Definition

The product is a reusable starter template, not a one-off demo.

It must provide:

- An iOS app with a polished ChatGPT-style chat interface.
- A backend that brokers all communication with the OpenAI Agents SDK.
- A simple user experience: the frontend is only a chat surface where the user talks to the agent.
- A backend architecture that supports highly customizable agents out of the box.

## Core Requirements

### Frontend

- Use SwiftUI unless there is a strong, documented reason not to.
- The app should feel visually similar to the ChatGPT iOS app in layout, tone, spacing, and interaction patterns.
- Do not copy proprietary assets, branding, or exact visual details. Match the product feel, not the brand.
- Use this design contract unless there is a strong reason to diverge:
  - single primary transcript view with clear user and assistant message separation
  - bottom-anchored composer with restrained controls
  - generous spacing, calm typography, and minimal chrome
  - subtle motion only where it improves perceived responsiveness
  - no copied OpenAI marks, product names in UI chrome, proprietary icons, or clone-level visual imitation
- Keep the frontend intentionally narrow in scope:
  - conversation list or current conversation view
  - message composer
  - streaming or incremental assistant responses if practical
  - loading, error, and retry states
  - basic conversation history handling if it materially improves the template
- Do not add product ideas that turn this into a different app. No agent builder UI, no complex settings surface, no admin console, no workflow editor unless it is essential for local development or validation.
- Frontend customization is not the goal. The frontend should stay generic and chat-focused.

### Backend

- Use the OpenAI Agents SDK as the source of truth for agent behavior.
- Use official OpenAI documentation to verify SDK capabilities, supported patterns, and current integration details before making architectural decisions.
- The backend must be designed so a developer can configure or replace agents without rewriting the app.
- Support these core Agents SDK extension points out of the box:
  - model and instructions
  - tools
  - handoffs
  - guardrails if applicable
  - sessions or conversation state where relevant
  - MCP integration
- Prefer SDK-native composition and straightforward configuration over building a large abstraction layer that mirrors the SDK.
- Prefer configuration-driven agent definitions or other straightforward extension points so backend behavior can change without frontend changes.
- For SDK features not implemented by default, leave documented extension seams rather than promising full parity up front.
- The backend should be minimal, legible, and easy to extend.

## Architecture Expectations

- Keep the system simple enough that a single engineer can understand and maintain it quickly.
- Separate concerns clearly:
  - iOS client
  - backend service
  - shared contracts or API schemas if needed
  - environment/configuration handling
- Favor explicit data flow and straightforward types over clever abstractions.
- Avoid premature generalization. Build only the structure needed to support the stated requirements cleanly.
- Design for scale in the practical sense:
  - clear boundaries
  - maintainable code
  - predictable configuration
  - sane error handling
  - room to grow without major rewrites

## Implementation Principles

- Functional beats clever.
- Readable beats abstract.
- Simple beats magical.
- Use established patterns and official documentation rather than inventing custom frameworks.
- Prefer boring, dependable code.
- Document important decisions where they will matter to the next engineer.

## Autonomy Rules

- Work autonomously and make reasonable decisions without waiting for user input.
- Do not stop to ask questions unless a decision would create major product risk and cannot be answered from the codebase or official documentation.
- When requirements are ambiguous, choose the simplest interpretation that still satisfies the product definition.
- If the repository is missing needed structure, create it.
- If a dependency, integration detail, or SDK behavior is uncertain, verify it from official documentation before building around it.
- If something cannot be completed exactly as imagined, implement the closest robust version and document the gap clearly.

## Quality Bar

- The codebase must be clean, lean, and easy to maintain.
- Favor small files and focused types where that improves clarity.
- Keep naming direct and unsurprising.
- Add comments only where they save real reader effort.
- Remove dead code and avoid placeholder complexity.
- Include enough setup and documentation that another engineer can run the template without reverse engineering the repo.

## Workflow Expectations

- Build in small, coherent steps. 
- Keep the project runnable as work progresses. Avoid large unverified changesets.
- Commit changes as meaningful milestones are completed.
- Use the `$review-engineering-decisions` skill to review important commits as work progresses.
- Treat review findings seriously and keep the architecture tidy.
- Do not leave the repo in a half-finished state.  a milestone can be completed in the current session, complete it.
- I won't be around to help you with this project, so you need to be able to complete the project on your own. I'll be asleep.

## Definition of Done

The task is complete when all of the following are true:

- There is a working iOS app template with a high-quality chat-first interface.
- There is a working backend integrated with the OpenAI Agents SDK.
- The iOS app can send messages to the backend and receive agent responses.
- The backend is structured for real agent customization, not a narrow demo path.
- The project is understandable from the repository layout and documentation.
- Setup and run instructions are present.
- Environment configuration examples or templates are present.
- There is at least a basic verification path such as smoke tests, manual test steps, or scripted checks for critical flows.
- Important assumptions and tradeoffs are documented.
- The implementation is maintainable and free of unnecessary complexity.

## Non-Goals

Unless required to make the template functional, do not spend time on:

- feature bloat
- experimental architecture
- excessive frontend customization
- elaborate dashboards or control panels
- speculative abstractions for future use cases that are not yet needed

## Recommended Capabilities

Use relevant skills and tools when they materially improve the result, especially:

- `build-ios-apps:ios-debugger-agent`
- `build-ios-apps:swiftui-liquid-glass`
- `build-ios-apps:swiftui-performance-audit`
- `build-ios-apps:swiftui-ui-patterns`
- `build-ios-apps:swiftui-view-refactor`
- `$review-engineering-decisions`

## Final Standard

Deliver a template that feels like a real starting point for a serious app: minimal, polished, extensible, and ready for another engineer to pick up without confusion.