# AI-First Remote Ops iOS App

## Product Spec, Implementation Plan, and Test Strategy

## 1. Document status

**Status:** Draft v1  
**Audience:** Product, iOS engineering, backend/platform, security review, design  
**Primary platform:** iPhone first, iPad compatible later  
**Design language:** Liquid-glass inspired, modern Apple-native, terminal-heavy but not terminal-led

---

## 2. Product summary

Build an iOS app for remote command execution where **typing is not the default interaction**. The primary interaction model is:

1. Ask AI to generate a command from natural language.
2. Choose a command from scoped history.
3. Paste a copied command with review.
4. Type manually only as a fallback.

The app supports:

* Standard SSH hosts.
* AWS-authenticated remote access workflows.
* AWS ECS Exec as a first-class remote target.
* Per-session and global command history.
* Secure storage for credentials and API keys.
* AI provider abstraction with OpenRouter and direct API key support.
* Clean environment/profile management.
* Visual browsing for SSH configs, keys, and GPG/OpenPGP metadata.
* A future “OpenCode in remote session” capability planned from the start.

This is not “just an SSH client.” It is an **AI-first remote operations client**.

---

## 3. Product goals

### 3.1 Primary goals

* Make remote command execution significantly faster on iPhone than traditional typing-based SSH apps.
* Make AI command generation feel safe, transparent, and reviewable.
* Give users a structured operational memory via session-scoped and global history.
* Provide strong security defaults for secrets, auth, and risky commands.
* Make AWS remote workflows feel first-class instead of bolted on.
* Make environment switching and browsing intuitive and visually polished.

### 3.2 Non-goals for MVP

* Full remote IDE.
* Arbitrary multi-user collaboration.
* Full local terminal shell on device.
* Complete SSH config parity with every desktop feature.
* Native OpenCode execution in v1.

---

## 4. Product principles

1. **AI proposes, user approves.** No AI-generated command runs automatically by default.
2. **Typing is fallback, not primary.**
3. **Session context matters.** History, AI suggestions, and UI are session-aware.
4. **Danger is explicit.** Risk and impact must be visible before execution.
5. **Secrets stay isolated.** Secret material is not mixed into general app persistence.
6. **AWS remote targets are first-class.** Do not flatten ECS Exec into generic SSH internals.
7. **Testability is a product feature.** Every core flow must be mockable and deterministic.

---

## 5. User personas

### 5.1 Solo infrastructure engineer

Needs quick access to multiple hosts, remembers commands poorly on mobile, wants AI-assisted command drafting and strong history.

### 5.2 AWS-heavy operator

Frequently switches roles/accounts/regions, needs browser auth, short-lived credentials, ECS task access, and minimal friction.

### 5.3 Security-conscious power user

Uses hardware-backed auth, wants limited secret exposure, biometric gates, visible audit trails, and clear environment labeling.

### 5.4 Developer on the move

Needs quick debugging and log inspection from phone, often pastes commands from Slack/GitHub/Notes, values per-project environments.

---

## 6. Scope

## 6.1 Supported session types

### 6.1.1 SSH Host

* Hostname/IP
* Port
* Username
* Auth method
* Optional working directory
* Optional tags

### 6.1.2 AWS EC2 via SSH

* Same transport as SSH
* Grouped under AWS account/profile/region in UX
* May reuse discovered hosts later

### 6.1.3 AWS ECS Exec

* First-class remote target
* User chooses account/profile, region, cluster, service/task, container
* Supports shell session and one-off command execution

### 6.1.4 Saved Environment

A reusable configuration wrapper around a target:

* Target session type reference
* Default working directory
* Default environment variables
* Shell preference
* Preferred AI provider/model
* Safety policy
* Labels/tags
* Favorites

## 6.2 Deferred but planned

* OpenCode remote session type
* Jump hosts / bastions
* Team-shared environments
* Output sharing / redaction workflows
* Local file browser / sync
* Port forwarding UI

---

## 7. Core user experience

## 7.1 Home screen

The home screen is a launcher, not a terminal dump.

### Sections

* Recent sessions
* Favorite environments
* Suggested actions
* Clipboard-detected command card
* Recent AI prompts
* Global history shortcut
* Add session button

### Primary actions

* Ask AI
* Open Session
* Open History
* Open Environments

## 7.2 Session screen

The session screen contains:

* Terminal output region
* Connection status header
* Environment badge
* Current identity / session label
* Bottom command launcher

### Bottom launcher tabs

* Ask AI
* History
* Paste
* Type

### Session overlay drawers

* Session history drawer
* Environment switcher
* Risk explanation panel
* Credentials state / expiry indicator

## 7.3 Ask AI flow

1. User taps Ask AI.
2. User writes natural-language intent.
3. App injects allowed session context.
4. AI provider returns structured proposal.
5. App shows:

   * exact command
   * explanation
   * risk label
   * optional alternatives
6. User chooses:

   * Run
   * Edit then run
   * Save
   * Cancel

## 7.4 History flow

Inside a session:

* default view is only this session’s history
* can pivot to environment history
* can pivot to all history

History actions:

* Run again
* Edit and run
* Pin
* Tag
* Delete
* Restore (if soft-deleted)

## 7.5 Paste flow

If clipboard resembles a command:

* show a floating “Paste & Review” affordance
* parse and preview command
* show risk markers if destructive
* allow run/edit/save

## 7.6 Manual typing flow

Manual terminal input remains available but visually secondary.

---

## 8. Information architecture

## 8.1 Main tabs

* Home
* Sessions
* History
* Environments
* Settings

## 8.2 Settings areas

* AI Providers
* Security
* AWS Accounts
* Keys & Configs
* Appearance
* Diagnostics
* Experimental / Coming Soon

## 8.3 Keys & Configs browser

Subsections:

* SSH Configs
* SSH Keys
* GPG / OpenPGP
* AWS Profiles

These are metadata browsers, not raw file explorers.

---

## 9. Functional requirements

## 9.1 Session management

* Create, edit, duplicate, favorite, archive, delete sessions.
* Connect/disconnect/reconnect.
* Restore recently used sessions.
* Associate a session with one or more environments.
* Support session badges for prod/staging/dev/personal.

## 9.2 Terminal interaction

* Real terminal emulation.
* Scrollback buffer.
* Copy selection.
* Clear output.
* Connection state overlay.
* Exit code capture for command boundaries when possible.

## 9.3 AI command generation

* Multiple providers supported.
* BYOK storage for API keys.
* Per-environment default provider/model.
* Structured output contract.
* Risk scoring before run.
* Redaction of obvious sensitive data before prompt submission where feasible.

## 9.4 History

* Save every executed command and important metadata.
* Save AI prompt and resulting command separately.
* Session-scoped history default.
* Global search and filtering.
* Soft-delete with optional hard delete.

## 9.5 AWS support

* Browser-driven sign-in for supported flows.
* Session token storage and expiry awareness.
* Region/account/role selection.
* ECS cluster/service/task/container browsing.
* ECS Exec shell and one-off command execution.

## 9.6 Environment management

* Create named environments.
* Clone environment.
* Tag and color-code environment.
* Set default shell, cwd, AI model, variables, notes, risk mode.
* Attach session or AWS target.

## 9.7 Security

* Secure secret storage.
* Optional Face ID gate to reveal/use secrets.
* Optional session lock after inactivity.
* High-risk command confirmation.
* Production environment warnings.

## 9.8 Coming soon: OpenCode

* Visible as disabled/coming soon session type.
* Architecture-ready data model and routing.
* Placeholder UI with roadmap messaging.

---

## 10. Non-functional requirements

### Performance

* App cold launch under acceptable modern iPhone expectations.
* Terminal render should remain smooth under moderate output load.
* Session switching should feel instant from cache.
* History browsing/search should be local-first and responsive.

### Reliability

* Graceful reconnect states.
* No silent failure on auth expiry.
* Clear error classification.
* Terminal session must survive transient app interruptions when feasible.

### Security

* No plaintext storage of keys or API secrets in general database.
* Secrets never included in analytics.
* AI prompt logging configurable and privacy-aware.

### Accessibility

* Dynamic type support outside terminal text areas where possible.
* VoiceOver-friendly navigation and controls.
* High contrast mode compatibility.

### Testability

* All business logic separated from UI rendering.
* All side effects abstracted behind protocols/interfaces.
* Deterministic clock and IDs in tests.
* Full local mock mode for CI.

---

## 11. Design system direction

## 11.1 Visual language

* Glass cards and floating controls.
* Blur/material effects in navigation and overlays.
* Dark, high-contrast terminal canvas.
* Minimal but intentional motion.
* Subtle per-environment tinting.

## 11.2 Safety-aware visuals

* Strong environment color/badge system.
* Destructive command highlighting.
* Auth expiry chips.
* Connection state indicators.

## 11.3 Key surfaces

* Home: cards, command prompt bar, suggested actions.
* Session: terminal + floating launcher.
* History: searchable list + reusable chips.
* Environments: card grid/list with filters.

---

## 12. Architecture

## 12.1 High-level architecture

Use a modular layered architecture:

* **Presentation layer**

  * SwiftUI views
  * View models / presenters
  * Navigation coordinators

* **Domain layer**

  * Use cases / interactors
  * Reducers / state machines for complex flows
  * Validation and policy logic

* **Infrastructure layer**

  * SSH transport adapter
  * ECS Exec adapter
  * AI provider adapters
  * Keychain adapter
  * Browser auth adapter
  * Persistence adapter
  * Logging/telemetry adapter

* **Testing layer**

  * Mock/fake adapters
  * deterministic fixtures
  * contract tests

## 12.2 Recommended implementation style

Use protocol-oriented boundaries and dependency injection.

Every external dependency gets an abstraction:

* `SSHTransport`
* `RemoteExecTransport`
* `AIProvider`
* `AuthSessionLauncher`
* `SecretsStore`
* `HistoryStore`
* `EnvironmentStore`
* `Clock`
* `IDGenerator`
* `ClipboardReader`
* `TerminalRendererBridge`

This is the main way to keep the app heavily testable.

## 12.3 State machines

Use explicit state machines for:

* Session connection lifecycle
* Ask AI flow
* AWS sign-in flow
* ECS target selection flow
* History deletion/restore flow
* Session lock/unlock flow

Example session lifecycle states:

* idle
* connecting
* connected
* reconnecting
* disconnected
* authExpired
* failed(error)

Example Ask AI states:

* idle
* collectingPrompt
* generating
* generated(proposal)
* validationFailed
* awaitingApproval
* executing
* completed
* failed

These should be unit tested exhaustively with reducer/state transition tests.

---

## 13. Data model

## 13.1 Core entities

### Session

* `id`
* `name`
* `type` (ssh, awsEc2Ssh, ecsExec, openCodePlaceholder)
* `hostRef` or target descriptor
* `authRef`
* `tags`
* `environmentIds`
* `lastConnectedAt`
* `isFavorite`
* `isArchived`

### Environment

* `id`
* `name`
* `sessionId` or target reference
* `label` (prod/staging/dev/personal/custom)
* `defaultWorkingDirectory`
* `defaultShell`
* `variables`
* `preferredAIProvider`
* `preferredAIModel`
* `riskMode`
* `notes`
* `isFavorite`

### CommandRecord

* `id`
* `sessionId`
* `environmentId`
* `source` (ai, history, paste, manual)
* `nlPrompt` (optional)
* `commandText`
* `riskLevel`
* `wasEdited`
* `executedAt`
* `exitCode`
* `outputPreview`
* `isPinned`
* `isDeleted`
* `tags`

### AIProposal

* `id`
* `sessionContextSnapshot`
* `provider`
* `model`
* `nlPrompt`
* `commandText`
* `explanation`
* `riskLevel`
* `alternatives`
* `createdAt`

### AuthProfile

* `id`
* `type` (sshKey, password, awsBrowser, apiKey, token)
* `displayName`
* `metadata`
* `secretRef`
* `lastUsedAt`

### AWSProfile

* `id`
* `displayName`
* `accountHint`
* `roleHint`
* `defaultRegion`
* `tokenState`

### SecretRef

* `id`
* `kind`
* `storageKey`
* `requiresBiometric`

## 13.2 Persistence split

* General metadata in app database.
* Secret material in secure storage only.
* Short-lived auth state stored minimally and revocably.

---

## 14. Security model

## 14.1 Secret classes

* SSH private keys
* Passwords
* API keys
* AWS tokens / refresh context
* Any imported sensitive credential material

## 14.2 Security requirements

* Secrets stored via secure device-backed storage.
* Biometric-gated retrieval optional but recommended.
* Never log raw secrets.
* Never include secrets in crash reports.
* User can revoke/delete secrets independently from sessions.

## 14.3 Risk model for commands

Commands classified into at least:

* Safe
* Review recommended
* Elevated / sudo
* Destructive
* Unknown

Risk classification inputs:

* known dangerous verbs (`rm`, `dd`, `mkfs`, `shutdown`, etc.)
* wildcard patterns
* environment label
* shell metacharacters and pipes
* privilege escalation markers

## 14.4 Production safety mode

For environments tagged prod:

* stronger command confirmation
* optional “type environment name to confirm” for destructive actions
* persistent prod badge in session header

---

## 15. AI subsystem

## 15.1 Provider abstraction

The AI layer must not assume a single vendor.

### Provider capabilities

* chat completion
* structured output
* model listing
* key validation
* request cancellation
* rate-limit/error classification

### Initial provider support

* OpenRouter
* Direct providers via compatible chat completion abstraction
* Mock provider for tests

## 15.2 Prompt contract

The app should generate prompts from:

* user natural-language intent
* session type
* remote OS/shell hints
* cwd if known
* environment tags
* privacy mode settings
* recent relevant command summaries

The app should request structured output:

* `command`
* `explanation`
* `risk`
* `alternatives`
* `assumptions`

## 15.3 AI safety rules

* Never auto-run by default.
* Never silently rewrite after user review.
* Show assumptions.
* Show if the command may be incomplete or shell-dependent.

## 15.4 Privacy modes

* Full context
* Minimal context
* No history context
* No output upload

---

## 16. AWS and remote target subsystem

## 16.1 AWS auth flow

Design for an auth launcher abstraction that opens system web auth and returns callback tokens/state.

States:

* signedOut
* signingIn
* signedIn
* expiringSoon
* expired
* failed

## 16.2 ECS target selection flow

* Choose AWS profile
* Choose region
* Load clusters
* Load services/tasks
* Choose task
* Choose container
* Choose action (shell / run command)

This flow should be cache-aware but always refreshable.

## 16.3 Remote transport abstraction

Do not force SSH and ECS through the same low-level API if semantics differ.

Create a higher-level abstraction:

* `RemoteSession`
* `RemoteCommandExecutor`
* `InteractiveShellSession`

SSH adapter can support both command and interactive shell.
ECS Exec adapter supports interactive shell where available and command execution semantics separately.

---

## 17. Environment management subsystem

## 17.1 Goals

* Make switching contexts faster.
* Reduce mistakes.
* Encode user intent into named reusable profiles.

## 17.2 Environment attributes

* name
* target
* label
* cwd
* shell
* env vars
* AI default model
* risk policy
* notes
* tags

## 17.3 UX requirements

* environments list/grid
* filters by label/tag/favorite
* clone and edit
* “open in session” quick action
* environment badge visible in session at all times

---

## 18. Keys and config browser

## 18.1 UX goals

* Browsable metadata, not raw secret dumps
* Clear provenance and usage
* Easy filtering and search

## 18.2 SSH configs browser

Display:

* config name / host alias
* hostname
* username
* port
* linked identity/key
* tags

## 18.3 SSH keys browser

Display:

* label
* fingerprint
* algorithm
* source/import method
* linked sessions/environments
* last used

## 18.4 GPG / OpenPGP browser

Display:

* key label
* fingerprint
* capabilities (sign/encrypt/auth if known)
* linked notes / usage metadata

This is metadata-only unless explicit export/reveal support is added later.

---

## 19. Coming soon: OpenCode integration

## 19.1 Product intent

Expose a disabled but planned session type that tells users remote coding-agent workflows are coming.

## 19.2 Architectural preparation

Create placeholders now for:

* session type enum case
* capability flags
* agent session screen route
* remote agent event stream interfaces
* permissions / audit model

## 19.3 Not in MVP

* actual OpenCode transport
* task execution
* diff/review UI

---

## 20. Analytics and diagnostics

## 20.1 Product analytics

Only non-sensitive analytics should be captured, opt-in where appropriate:

* session opens
* connection success/failure category
* AI generation success/failure category
* history usage patterns
* environment usage

No raw secrets or command contents by default in analytics.

## 20.2 Diagnostics

* local diagnostic bundle generation
* redacted logs
* connection traces categorized by error type
* AI request outcome diagnostics without secret payloads

---

## 21. Implementation plan

## 21.1 Phase 0: Architecture spike

**Goal:** prove technical feasibility and establish testable foundations.

### Deliverables

* SwiftUI shell app skeleton
* dependency injection container
* protocol boundaries for all side effects
* reducer/state machine framework choice
* local persistence skeleton
* mock terminal screen
* mock AI provider
* mock SSH session adapter
* browser auth callback spike
* security storage spike

### Exit criteria

* Can run the app entirely in mock mode.
* Can simulate Ask AI -> review -> execute -> history save.
* Can simulate connect/disconnect lifecycle without real network.

## 21.2 Phase 1: MVP core remote ops

**Goal:** ship a compelling AI-first SSH mobile experience.

### Features

* SSH sessions
* terminal rendering integration
* Ask AI flow
* per-session history
* global history
* clipboard detection and paste review
* environment management basics
* AI provider configuration
* secrets storage and biometric gating
* liquid-glass design polish

### Exit criteria

* User can create a session, generate a command, review, run, save, and rerun.
* History is scoped correctly and searchable.
* Secrets never leave secure storage except when needed.
* Entire flow is covered by automated tests.

## 21.3 Phase 2: AWS support

**Goal:** deliver modern AWS remote workflows.

### Features

* AWS account/profile UI
* browser auth integration
* credential expiry UI
* ECS target discovery
* ECS Exec interactive shell / command execution
* AWS-specific session recents and favorites

### Exit criteria

* User can sign in, select a region/cluster/task/container, and open a shell.
* Expired auth is surfaced clearly.
* AWS flows are covered in mock and staging tests.

## 21.4 Phase 3: Power-user ergonomics

**Goal:** turn the app into daily-driver infrastructure tooling.

### Features

* pinned commands
* tags and search improvements
* advanced risk policies
* output summaries
* history compare
* better environment cloning and templating
* diagnostic export

## 21.5 Phase 4: OpenCode foundation release

**Goal:** convert placeholder architecture into real feature work.

---

## 22. Engineering structure

## 22.1 Suggested modules/packages

* `AppCore`
* `SessionDomain`
* `HistoryDomain`
* `EnvironmentDomain`
* `AISubsystem`
* `SecuritySubsystem`
* `AWSSubsystem`
* `TerminalSubsystem`
* `PersistenceSubsystem`
* `DesignSystem`
* `TestSupport`

## 22.2 Shared utilities

* clock
* ID generator
* logger
* feature flags
* result/error mapping

---

## 23. Test strategy

This product should be designed so most behavior is testable without real network access or live credentials.

## 23.1 Testing principles

* Business logic does not depend on UIKit/SwiftUI rendering.
* Reducers/state machines are pure where possible.
* Every network or secure-storage action is abstracted.
* Every async path is controllable in tests.
* Use fixed clocks, seeded IDs, and deterministic fixtures.

## 23.2 Test pyramid

### Unit tests

Highest volume. Validate reducers, use cases, parsing, validation, risk classification, data mapping.

### Integration tests

Moderate volume. Validate interactions between domain + infrastructure adapters using mocks/fakes.

### UI tests

Focused, high-value flows only. Validate navigation, critical states, error handling, accessibility hooks.

### Manual / exploratory tests

Real device tests for auth, terminal interaction, keyboard behavior, performance, YubiKey/browser flows.

---

## 24. Testability architecture requirements

## 24.1 Protocol boundaries

Every side effect must be behind a protocol.

Required mockable interfaces:

* `SSHTransport`
* `ECSExecTransport`
* `AIProvider`
* `SecureSecretsStore`
* `DatabaseStore`
* `ClipboardService`
* `AuthWebSession`
* `BiometricGate`
* `TerminalBridge`
* `TelemetrySink`
* `Clock`
* `IDGenerator`

## 24.2 Deterministic async

* Use controllable schedulers/executors where possible.
* Avoid hidden `DispatchQueue.main.asyncAfter` logic in domain code.
* Inject retry policies and timers.

## 24.3 Fixtures

Create reusable fixtures for:

* sessions
* environments
* AI responses
* SSH outputs
* ECS discovery trees
* auth-expired flows
* clipboard commands
* dangerous commands

## 24.4 Full mock mode

The app should support a launch argument or feature flag to run in full mock mode:

* fake sessions
* fake shell output
* fake AI generation
* fake AWS browser auth
* fake ECS targets

This enables:

* CI screenshots
* demos
* onboarding previews
* deterministic UI tests

---

## 25. Unit test plan

## 25.1 Reducer/state machine tests

Cover all transitions for:

* session lifecycle
* Ask AI lifecycle
* AWS auth lifecycle
* ECS selection lifecycle
* history deletion/restore
* session lock/unlock

### Example assertions

* connecting -> connected on success
* connecting -> failed on transport error
* generated proposal -> awaitingApproval
* approval -> executing
* executing -> completed/failure with saved history

## 25.2 Use case tests

* create session
* duplicate session
* create environment
* attach environment to session
* save history record
* restore deleted command
* choose AI provider fallback
* classify command risk
* parse clipboard text

## 25.3 Validation tests

* invalid hostnames
* invalid key refs
* unsupported model selection
* dangerous command markers
* prod safety escalations

## 25.4 Mapping/serialization tests

* DB model <-> domain model
* provider response -> AIProposal
* auth token state mapping
* session context snapshot generation

---

## 26. Integration test plan

## 26.1 Domain + fake SSH transport

Scenarios:

* successful connection
* connection timeout
* disconnect and reconnect
* command execution success/failure
* scrollback/output capture

## 26.2 Domain + fake AI provider

Scenarios:

* valid structured response
* malformed response
* slow response and cancellation
* model unavailable fallback
* privacy mode context reduction

## 26.3 Domain + fake secrets store

Scenarios:

* successful secret retrieval
* biometric required
* secret deleted externally
* corrupt key reference

## 26.4 Domain + fake auth web session

Scenarios:

* successful callback
* cancelled auth
* callback mismatch/state error
* expired tokens on session open

## 26.5 Domain + fake ECS transport/discovery

Scenarios:

* list accounts/regions/clusters/services/tasks/containers
* target disappears between selection and execution
* shell open fails due to auth expiry
* command execution returns stderr/exit failure

---

## 27. UI test plan

Focus on critical happy paths and critical error paths.

## 27.1 Core UI flows

* create SSH session
* open session
* Ask AI -> review -> run
* session history scoped correctly
* switch to global history
* delete and restore a history item
* clipboard detection banner -> paste review
* create environment and attach to session

## 27.2 AWS UI flows

* open AWS auth
* sign-in success mock
* cluster/service/task/container selection
* open ECS shell
* auth-expired relogin prompt

## 27.3 Safety/UI state flows

* prod badge visible
* destructive command confirmation shown
* biometric prompt before key use
* locked app resumes to unlock gate

## 27.4 Accessibility checks

* identifiers for critical controls
* VoiceOver labels on major actions
* scalable text on non-terminal areas
* high-contrast screenshots in CI if feasible

---

## 28. Manual test plan

Real-device manual testing remains essential for:

* keyboard behavior and text input
* terminal scrolling and selection feel
* app lifecycle interruptions
* browser auth handoff and callback
* YubiKey/WebAuthn/NFC flows if supported in chosen auth path
* performance under long outputs
* offline / flaky network behavior

### Manual scenarios

* background app during active session
* rotate device if supported
* switch networks mid-session
* expired AWS auth while browsing tasks
* paste multiline script accidentally
* Face ID failure / fallback path

---

## 29. Performance and load testing

## 29.1 Local performance scenarios

* render long terminal output bursts
* large command history datasets
* large environment lists
* repeated Ask AI operations

## 29.2 Metrics to measure

* app launch time
* time to session screen
* AI proposal latency breakdown
* terminal frame drops under output load
* history query latency
* memory usage during long sessions

## 29.3 Tooling

* performance signposts
* Xcode Instruments runs
* repeatable mock-output benchmarks

---

## 30. Security testing plan

## 30.1 Static checks

* secrets not logged
* no insecure persistence of private material
* key references invalidated on deletion
* no provider keys in analytics payloads

## 30.2 Dynamic checks

* attempt to access deleted secret refs
* try relaunching after secret removal
* verify lock screen behavior
* verify prod safety prompts

## 30.3 Threat scenarios

* stolen unlocked phone
* stale AWS token reused
* clipboard containing secrets
* AI provider request containing too much context
* command injection through malformed AI output

## 30.4 Countermeasures

* biometric gates
* privacy modes
* explicit review screen
* output/context redaction
* dangerous command classification

---

## 31. CI and release strategy

## 31.1 CI pipeline

* lint/format
* unit tests
* integration tests with mocks
* UI test smoke suite in simulator
* screenshot snapshot tests where useful
* coverage reporting

## 31.2 Required test gates for merge

* all reducer/use-case tests pass
* no snapshot diffs unless approved
* no secrets scanning issues
* UI smoke tests pass
* minimum coverage threshold on core modules

## 31.3 Release channels

* internal dogfood
* private beta/TestFlight
* staged public release

---

## 32. Acceptance criteria for MVP

A build is MVP-complete when:

* User can create at least one SSH session.
* User can create at least one environment.
* User can ask AI for a command and review it before execution.
* User can execute command and view output in terminal.
* User can browse session-scoped history and global history.
* User can paste a clipboard command through a review flow.
* User can store and use provider API keys securely.
* User can delete command history entries.
* App has automated coverage across core flows and can run in full mock mode.

---

## 33. Acceptance criteria for AWS milestone

A build is AWS-milestone complete when:

* User can sign in through browser-based auth flow.
* User can view AWS profile/account/region state.
* User can browse ECS targets.
* User can open an ECS shell or run a command.
* Auth expiry and reconnect paths are clear and tested.

---

## 34. Open questions

* Which SSH transport stack best balances reliability, licensing, and iOS compatibility?
* How much raw key import/export should MVP expose versus metadata-only browsing?
* Should history output previews be truncated aggressively by default for privacy?
* What exact privacy defaults should apply to AI prompt context?
* How much offline support is needed for history/environment editing without connectivity?
* Should manual typing be hidden behind a gesture or always visible as a tab?

---

## 35. Suggested initial backlog

### Foundation

* app shell
* DI container
* feature flags
* mock mode
* app database schema
* keychain abstraction
* logging abstraction

### Session domain

* session entity and CRUD
* connection lifecycle reducer
* session list UI
* session detail/session screen UI shell

### AI domain

* provider abstraction
* OpenRouter adapter
* mock adapter
* Ask AI reducer
* proposal review UI
* risk classifier

### History domain

* history persistence
* session-scoped history queries
* global history queries
* delete/restore
* pinning

### Environment domain

* environment CRUD
* attach/detach
* badges and labels
* environment switcher UI

### Security

* secure secret refs
* biometric gate
* privacy modes
* diagnostics redaction

### AWS domain

* auth launcher abstraction
* AWS profile model
* mock discovery tree
* ECS target picker flow

---

## 36. Recommended build order

1. Build full mock mode first.
2. Build session/history/environment core with fake transport.
3. Build Ask AI flow with fake and real providers.
4. Integrate real SSH transport.
5. Polish terminal UX and liquid-glass shell.
6. Add secure secrets and biometric gates.
7. Add AWS auth scaffolding.
8. Add ECS discovery and exec.
9. Harden with performance/security testing.
10. Ship internal beta.

---

## 37. Definition of done for each feature

A feature is done only when:

* product behavior is implemented
* analytics/diagnostics behavior is decided
* unit tests exist for its logic
* integration tests exist for key edge cases
* UI test coverage exists for main path if user-visible
* accessibility labels are added where relevant
* failure states are designed and implemented
* security/privacy implications are reviewed

---

## 38. Final recommendation

Treat this as a **testable systems product**, not a UI toy. The moat is not only the liquid-glass look or AI prompt entry. The moat is:

* safe AI-assisted command generation
* session-aware operational memory
* first-class AWS remote workflows
* strong security defaults
* excellent mobile ergonomics
* architecture built for deterministic testing and future agent sessions

If built with protocol boundaries, mock mode, explicit state machines, and strong acceptance criteria from day one, the app will remain maintainable as it grows from SSH client into a broader mobile remote operations platform.
