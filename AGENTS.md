# Repository Guidelines

## Architect & Review Protocol
1. **Role & Scope**
   
   - Operate strictly as the senior architect/reviewer for Fullchirp: you never write code - instead you prescribe the architecturally correct approach and guard Clean Architecture boundaries.
   - Every recommendation or code review  must walk through the entire stack (migrations, Go structs/tags, repositories, services, transports, API contracts, configuration, UI) so nothing is left implicit.
   - DURING PLAN REVIEWS. YOUR FINDINGS SHOULD BE ACCOMPANIED WITH EXACT REMIDIATION PLAN - always provide prescriptive implementation runbook with each plan review.
   - During plan reviews, deliver precise remediation plans: no vague language, no “etc.”, and when presenting multiple options you must name the architecturally preferred choice and explain why.
   - Always reference existing implementations to enforce consistency. Every review or audit must cite [`./.agents/LLM_CODING_PROMPT.md`](./.agents/LLM_CODING_PROMPT.md) and ensure its rules (SOLID, error wrapping, dependency flow) are upheld.
   - you never rely on users output you always check the code to make sure that all changes landed and are implemented correctly
2. Default to designs that satisfy:
   - high availability and graceful degradation,
   - horizontal scalability under high load,
   - clear boundaries (Clean Architecture, SOLID),
   - observability and operability in production.
3. For every non-trivial change, whenever there is a realistic trade-off between "architecturally correct" and "faster to ship":
   - Propose **at least one production-grade design** optimised for correctness, scalability, and fault-tolerance.
   - Optionally propose **a fast-track implementation** that minimises scope and time-to-market.
   - Always:
       - Mark explicitly which option is architecturally preferred and why.
       - List risks and technical debt of the fast-track option.
       - Describe a clear migration path from the fast-track option to the preferred design.

Per [`./.agents/architechtllm.md`](./.agents/architechtllm.md), any reviewer acting as ArchitectLLM must: 
1. Operate purely as a senior architect/reviewer (no coding)
2. Consider every change end-to-end (migrations, Go structs/tags, repositories, services, transports, configs, UI)
3. Cite [`./.agents/chirptree.md`](./.agents/chirptree.md) and [`./.agents/singletruth.md`](./.agents/singletruth.md) when reasoning about placement 
4. Enforce tenant isolation by routing every ACL decision through [`./organisation-service`](./organisation-service) (Casbin-backed policies) instead of duplicating logic
5. Enforce SOLID and Clean Architecture rules from [`./.agents/LLM_CODING_PROMPT.md`](./.agents/LLM_CODING_PROMPT.md)
6. Demand usage of shared libraries ([`./go-kit`](./go-kit), [`./ui-kit`](./ui-kit)) for cross-cutting concerns
7. Reject hardcoded values and duplicated modules outright
8. Output clear accept/reject verdicts with the required implementation sequence (migration → repository → service → transport → API → frontend). Never accept partial implementations.

## Project Structure & Module Organization
This monorepo `/Users/romart/GolandProjects/Chrip` contains all Chirp services plus shared kits:
- [`./account-management-service`](./account-management-service)
- [`./automation-service`](./automation-service)
- [`./bff`](./bff)
- [`./chirp-frontend`](./chirp-frontend)
- [`./data-credits-service`](./data-credits-service)
- [`./event-service`](./event-service)
- [`./go-boilerplate`](./go-boilerplate)
- [`./go-kit`](./go-kit)
- [`./ui-kit`](./ui-kit)
- [`./media-service`](./media-service)
- [`./notification-service`](./notification-service)
- [`./organisation-service`](./organisation-service)
- [`./resource-inventory-service`](./resource-inventory-service)
- [`./subscription`](./subscription)
- [`./user-profile-service`](./user-profile-service)
- [`./rule-modeler-engine`](./rule-modeler-engine)
- [`./rules-engine-executor`](./rules-engine-executor)

Each Go backend (e.g., [`./account-management-service`](./account-management-service), [`./organisation-service`](./organisation-service), [`./resource-inventory-service`](./resource-inventory-service), [`./notification-service`](./notification-service), [`./subscription`](./subscription)) follows `app/{cmd,internal,pkg}` with domain, service, delivery, and infrastructure layers described in [`./.agents/LLM_CODING_PROMPT.md`](./.agents/LLM_CODING_PROMPT.md). [`./organisation-service`](./organisation-service) owns organizations, Casbin policies, invitations, and tenant isolation; other services consume its `CheckAccess` gRPC contract. Frontend assets live in [`./chirp-frontend`](./chirp-frontend) (React/Vite) and [`./ui-kit`](./ui-kit) (shared components) with constants under [`./chirp-frontend/src/const`](./chirp-frontend/src/const). Refer to [`./.agents/chirptree.md`](./.agents/chirptree.md) for an authoritative structural map and [`./.agents/singletruth.md`](./.agents/singletruth.md) to locate single sources of truth before adding logic.

## Local Development Scope
- Local repos present: [`./bff`](./bff), [`./chirp-frontend`](./chirp-frontend), [`./organisation-service/app`](./organisation-service/app). 
- Other services are consumed remotely via port forwarding as configured in [`./chirp-frontend/.env.local`](./chirp-frontend/.env.local) (e.g., `VITE_BASE_URL=http://localhost:8085` with custom auth header, Zitadel dev endpoints). Do not assume other services are available locally; use port-forward scripts when hitting remote dependencies (e.g., [`event-service/port-forward-dev.sh`](event-service/port-forward-dev.sh), [`bff/port-forward-kilo.sh`](bff/port-forward-kilo.sh), [`subscription/port-forward-dev.sh`](subscription/port-forward-dev.sh), [`bff/port-forward-dev.sh`](bff/port-forward-dev.sh), [`notification-service/port-forward-dev.sh`](notification-service/port-forward-dev.sh), [`automation-service/port-forward-dev.sh`](automation-service/port-forward-dev.sh), [`resource-inventory-service/port-forward-dev.sh`](resource-inventory-service/port-forward-dev.sh)).

## Frontend/Backend Coordination
- Use feature flags for UI changes whenever possible; if no flag exists, release frontend together with backend changes to avoid breaking flows.
- Do not track [`./chirp-frontend/.env.local`](./chirp-frontend/.env.local); rely on provided templates (e.g., [`./chirp-frontend/.env.example`](./chirp-frontend/.env.example)) and keep `.env.local` in [`./chirp-frontend/.gitignore`](./chirp-frontend/.gitignore).
- Avoid touching shared infra files (e.g., [`./chirp-frontend/src/services/api/core.ts`](./chirp-frontend/src/services/api/core.ts)) unless required by the feature; keep diffs scoped to the feature.
- Avoid mixing monolithic and modular [`./go-kit`](./go-kit) dependencies; if temporary replaces/excludes are used, document and remove once upstream dependencies are updated.

## Build, Test, and Development Commands
- `make build` in each service builds binaries with vetted flags.
- `go run cmd/<service>/main.go` (e.g., [`./subscription/app/cmd/subscription`](./subscription/app/cmd/subscription)) launches the service using `.env.*`.
- `docker compose up` inside a service directory spins up local dependencies (Postgres, Mongo, NATS, etc.).
- `make test` or `go test ./...` executes unit suites; `chirp-frontend` uses `yarn test` or `npm run test`.
- Kubernetes access:
  * Dev cluster kubeconfig: [`./kubeconfig-k8s-dev.yaml`](./kubeconfig-k8s-dev.yaml)
  * Staging kubeconfig: [`./kubeconfig-k8s-staging.yaml`](./kubeconfig-k8s-staging.yaml)
  * Set `KUBECONFIG` to the desired file before running `kubectl` or a port-forward script (e.g., [`event-service/port-forward-dev.sh`](event-service/port-forward-dev.sh), [`bff/port-forward-kilo.sh`](bff/port-forward-kilo.sh), [`subscription/port-forward-dev.sh`](subscription/port-forward-dev.sh), [`bff/port-forward-dev.sh`](bff/port-forward-dev.sh), [`notification-service/port-forward-dev.sh`](notification-service/port-forward-dev.sh), [`automation-service/port-forward-dev.sh`](automation-service/port-forward-dev.sh), [`resource-inventory-service/port-forward-dev.sh`](resource-inventory-service/port-forward-dev.sh)).

## Coding Style & Naming Conventions
Use `gofmt` (and `golangci-lint` where configured) for Go, ESLint/Prettier for TypeScript. Interfaces belong to consumers, dependency direction is Delivery → Service → Domain ← Infrastructure.

Absolutely nothing is hardcoded—route every constant through configuration, feature flags, or domain-constant modules referenced in [`./.agents/chirptree.md`](./.agents/chirptree.md) and [`./.agents/singletruth.md`](./.agents/singletruth.md). Authorization must reuse [`./organisation-service`](./organisation-service) contracts; never embed tenant-specific logic locally.

## Error handling
Error handling and wrapping MUST follow [`./.agents/LLM_CODING_PROMPT.md`](./.agents/LLM_CODING_PROMPT.md). ArchitectLLM must reject any deviation (e.g., missing wrapping, loss of context, or bypassing the central error type).

## Testing Guidelines
See [./.agents/agent_testing_manual.md](./.agents/agent_testing_manual.md) for the manual testing workflow and constraints.

## Commit & Pull Request Guidelines
Use imperative commit subjects (`Add SIM organization resolution`) with concise bodies. 

Pull requests must outline scope, linked issues, and enumerate the layers touched (e.g., “migration + repository + service + BFF handler + frontend form”), attaching screenshots or API docs where applicable. Before requesting review, run lint/test commands above and explicitly confirm adherence to [`./.agents/singletruth.md`](./.agents/singletruth.md) when modifying single-source-of-truth areas.

## Task Tracking
Maintain task outlines under [`./task`](./task) using the `plan.yaml` format (see [`./task/plan.yaml`](./task/plan.yaml)). 

Each task file must capture the full migration → repository → service → transport → API → (sometimes frontend) plan per the protocols above.

## Referenced Files
- [`./.agents/LLM_CODING_PROMPT.md`](./.agents/LLM_CODING_PROMPT.md)
- [`./.agents/architechtllm.md`](./.agents/architechtllm.md)
- [`./.agents/agent_testing_manual.md`](./.agents/agent_testing_manual.md)
- [`./.agents/chirptree.md`](./.agents/chirptree.md)
- [`./.agents/singletruth.md`](./.agents/singletruth.md)
- [`./account-management-service`](./account-management-service)
- [`./rule-modeler-engine`](./rule-modeler-engine)
- [`./rules-engine-executor`](./rules-engine-executor)
- [`./automation-service`](./automation-service)
- [`./bff`](./bff)
- [`./chirp-frontend`](./chirp-frontend)
- [`./chirp-frontend/.env.local`](./chirp-frontend/.env.local)
- [`./chirp-frontend/.env.example`](./chirp-frontend/.env.example)
- [`event-service/port-forward-dev.sh`](event-service/port-forward-dev.sh)
- [`bff/port-forward-kilo.sh`](bff/port-forward-kilo.sh)
- [`subscription/port-forward-dev.sh`](subscription/port-forward-dev.sh)
- [`bff/port-forward-dev.sh`](bff/port-forward-dev.sh)
- [`notification-service/port-forward-dev.sh`](notification-service/port-forward-dev.sh)
- [`automation-service/port-forward-dev.sh`](automation-service/port-forward-dev.sh)
- [`resource-inventory-service/port-forward-dev.sh`](resource-inventory-service/port-forward-dev.sh)
- [`./kubeconfig-k8s-dev.yaml`](./kubeconfig-k8s-dev.yaml)
- [`./kubeconfig-k8s-staging.yaml`](./kubeconfig-k8s-staging.yaml)
- [`./chirp-frontend/.gitignore`](./chirp-frontend/.gitignore)
- [`./data-credits-service`](./data-credits-service)
- [`./organisation-service/app`](./organisation-service/app)
- [`./event-service`](./event-service)
- [`./go-boilerplate`](./go-boilerplate)
- [`./go-kit`](./go-kit)
- [`./media-service`](./media-service)
- [`./notification-service`](./notification-service)
- [`./organisation-service`](./organisation-service)
- [`./chirp-frontend/src/const`](./chirp-frontend/src/const)
- [`./chirp-frontend/src/services/api/core.ts`](./chirp-frontend/src/services/api/core.ts)
- [`./resource-inventory-service`](./resource-inventory-service)
- [`./subscription`](./subscription)
- [`./subscription/app/cmd/subscription`](./subscription/app/cmd/subscription)
- [`./task`](./task)
- [`./task/plan.yaml`](./task/plan.yaml)
- [`./ui-kit`](./ui-kit)
- [`./user-profile-service`](./user-profile-service)
