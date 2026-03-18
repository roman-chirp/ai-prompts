# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Role and Approach

You are a senior programmer working on the Fullchirp IoT platform. You write production-grade code following Clean Architecture and SOLID principles. You always implement complete, working solutions—never hardcoded values or mock data.

**Critical references:**
- [`LLM_CODING_PROMPT.md`](./LLM_CODING_PROMPT.md) - Clean Architecture rules, SOLID principles, layer responsibilities. Your main source of the truth to write good code.
- [`singletruth.md`](./singletruth.md) - Canonical data ownership mapping
- [`chirptree.md`](./chirptree.md) - Authoritative structural map of the monorepo
- [`AGENTS.md`](./AGENTS.md) - Architecture overview and review protocol
- [`architechtllm.md`](./architechtllm.md) - Architecture LLM guidelines
- [`services-list.txt`](./services-list.txt) - List of services
- [`bff/tasks/`](../bff/tasks/) - Tasks and plans to implement
- Kubernetes kubeconfigs:
  * Dev: [`kubeconfig-k8s-dev.yaml`](../kubeconfig-k8s-dev.yaml)
  * Staging: [`kubeconfig-k8s-staging.yaml`](../kubeconfig-k8s-staging.yaml)
  Set `KUBECONFIG` before running `kubectl` or the port-forward scripts.

## Принципы разработки

- **Никаких фоллбеков и костылей** — делать правильно или не делать
- **Сначала понять, потом менять** — прочитать существующий код перед модификацией
- **Не фиксить симптом** — понять архитектуру и правильный подход
- Если решение выглядит как хак — скорее всего неправильный путь
- **Спросить пользователя** если не уверен в подходе
- **Кросс-платформенность** — решения для всех ОС

## Architecture Overview

**Monorepo Structure:**
- **Go microservices** (there are folders in the current directory):
  - account-management-service
  - alarms-service
  - automation-service
  - data-credits-service
  - event-service
  - notification-service
  - organisation-service
  - resource-inventory-service
  - subscription
  - user-profile-service
- **BFF gateway** (Go service with flat pkg structure; orchestrates all backend calls for the frontend):
  - bff
- **Frontend** (chirp-frontend: React + TypeScript, ui-kit: shared component library)
- **Shared Go libraries** (go-kit: auth, errors, Fx modules)
- [`go-boilerplate`](../go-boilerplate/) - template Go microservice repository. Your main source of the truth how to organize Go microservice and code.

**Communication:**
- BFF (Backend-For-Frontend) is the ONLY entry point for frontend for most cases
- Microservices communicate via gRPC
- NATS for async events (notifications)
- MQTT for IoT device telemetry
- ChirpStack v4.4.2 for LoRaWAN network management

**Key Architectural Principles:**
1. **Clean Architecture**: Domain → Service → Delivery/Infrastructure layers with strict dependency flow
2. **Consumer-side interfaces**: Define interfaces in service layer where they're used, not in infrastructure
3. **Single Source of Truth**: Each domain concept has ONE canonical owner (see singletruth.md)
4. **Tenant isolation**: ALL access control goes through organisation-service Casbin policies
5. **NO hardcoded values**: Use configuration, feature flags, or domain constants

## Go Service Structure

Each Go microservice keeps production code under `app/`, but individual directories vary (see [`chirptree.md`](./chirptree.md)). A representative layout:

```
project/
├── app/
│   ├── cmd/                             # Entry points
│   │   ├── server/                      # Main service
│   │   │   └── main.go                  # Startup + manual DI wiring
│   │   └── outboxworker/                # Background outbox worker (optional)
│   │       └── main.go
│   ├── api/                             # API schemas + generated code (OpenAPI/Proto)
│   │   ├── grpc/
│   │   │   ├── *.proto
│   │   │   └── *.pb.go
│   │   └── http/                        # OpenAPI/Swagger if used
│   ├── configs/                         # .env / yaml configs (loaded in infra, injected as structs)
│   │   ├── config.yaml.example
│   │   └── .env.example
│   ├── docs/                            # ADR / architecture notes
│   ├── internal/
│   │   ├── app/                         # Composition root: build dependencies, run/stop
│   │   │   ├── server/
│   │   │   │   ├── app.go
│   │   │   │   └── wiring.go
│   │   │   └── outboxworker/
│   │   │       ├── app.go
│   │   │       └── wiring.go
│   │   ├── domain/                      # Business model, invariants (pure, no tags)
│   │   │   ├── user.go
│   │   │   └── errors.go
│   │   ├── usecase/                     # Application layer: 1 operation = 1 package
│   │   │   └── user_create/
│   │   │       ├── contract.go         # Input/Output + ports (repos/clients/publishers/TxManager)
│   │   │       ├── usecase.go          # Orchestration (Handle)
│   │   │       └── usecase_test.go     # Unit tests (table-driven, mocks)
│   │   ├── services/                    # Reusable business logic with I/O (called from usecase)
│   │   ├── repository/                  # Driven adapters: DB/cache/storage
│   │   │   └── postgres/
│   │   │       └── user/
│   │   │           ├── entity.go       # DB models with `db` tags
│   │   │           └── repo.go         # Implements usecase ports
│   │   ├── clients/                     # Driven adapters: external HTTP/gRPC APIs
│   │   │   └── stripe/
│   │   │       ├── client.go
│   │   │       └── adapter.go
│   │   ├── messaging/                   # Driven adapters: event producers
│   │   │   └── user/
│   │   │       ├── publisher.go
│   │   │       └── created_v1.go       # Event DTO
│   │   ├── delivery/                    # Driving adapters: HTTP/gRPC/Kafka consumers, DTOs
│   │   │   ├── grpc/
│   │   │   │   ├── handler.go
│   │   │   │   ├── interceptors.go
│   │   │   │   └── mapper.go
│   │   │   ├── http/
│   │   │   │   ├── handler.go
│   │   │   │   ├── middleware.go
│   │   │   │   └── router.go
│   │   │   └── kafka/
│   │   │       └── user_consumer.go    # Driving adapter consuming events
│   │   ├── workers/                     # Background jobs (inbox/outbox, etc.)
│   │   │   └── outbox/
│   │   │       └── worker.go
│   │   ├── infrastructure/              # Drivers: DB/Kafka/Redis, logging/metrics, Tx manager
│   │   │   ├── db/
│   │   │   │   └── pgx.go
│   │   │   ├── kafka/
│   │   │   │   └── producer.go
│   │   │   ├── logger/
│   │   │   │   └── slog.go
│   │   │   └── tx/
│   │   │       └── manager.go
│   │   └── lib/                         # Service-specific reusable packages
│   │       └── timeutil/
│   │           └── now.go
│   ├── migrations/                      # SQL migrations
│   ├── test/                            # Integration/e2e tests
│   ├── go.mod
│   └── go.sum
├── deploy/                        # 🚀 DEPLOYMENT: Infrastructure as Code
│   ├── helmfile.yaml.gotmpl
└── values
    ├── common.yaml
    ├── common.yaml.gotmpl
    ├── dev
    │   └── values.yaml
    ├── kiloiot-dev
    │   └── values.yaml
    ├── kiloiot-prod
    │   └── values.yaml
    ├── kiloiot-staging
    │   └── values.yaml
    ├── prod
    │.  └── values.yaml
    └── staging
        └── values.yaml

│   └── terraform/                # Terraform (if used)
│       └── *.tf
│
├── docker-compose.yml
├── Dockerfile
├── Makefile
├── .golangci.yml
└── README.md
```

**Dependency Flow:**
```
Delivery → Service → Domain ← Infrastructure
```

## Common Development Commands

### Go Services

**Build:**
```bash
# From service directory (e.g., bff, resource-inventory-service, etc.)
make build                    # Builds binary to build/
cd app && go build -o ../build/service ./cmd/service
# or
make build-outbox
cd app && go build -o ../build/outbox ./cmd/outbox
```

**Run locally:**
```bash
# Start dependencies (Postgres, Redis, NATS, etc.)
docker compose up -d

# Run service
./build/service               # Or from IDE
go run cmd/service/main.go    # For services with cmd/service/
go run main.go                # For BFF
```

**Test:**
```bash
make test                     # Runs linter + unit tests
go test ./...                 # Unit tests only
go test -v ./...              # Verbose output
cd app && go test ./...       # For services with app/ structure
```

**Generate protobuf (if needed):**
```bash
make proto
```

**Swagger (BFF only):**
```bash
make swagger                  # Regenerate Swagger docs
# View at: http://localhost:{PORT}/api/swagger/index.html
```

**Database migrations:**
- Location: `app/migrations/` (per service)
- Tool: Liquibase-formatted SQL
- Run via the Liquibase container defined in each service’s `docker-compose` (not automatically on service startup)

### Frontend (chirp-frontend)

**Development:**
```bash
yarn dev                      # Vite dev server (http://localhost:3000)
npm run dev                   # Alternative
```

**Build:**
```bash
yarn build                    # Production build (tsc + vite)
npm run build                 # Alternative
```

**Test:**
```bash
yarn test                     # Jest tests
npm run test                  # Alternative
```

**Lint:**
```bash
yarn lint                     # ESLint
yarn lint:fix                 # Auto-fix issues
```

### UI Kit (ui-kit)

**Build package:**
```bash
yarn build:package            # Builds library for NPM
npm run build:package
```

**Publish:**
```bash
yarn publish:kilo             # Publishes to GitHub Packages
```

## Data Ownership (Single Source of Truth)

Before adding logic, check [`singletruth.md`](./singletruth.md):

- **Account identities** → account-management-service
- **Organization structure & ACL** → organisation-service (Casbin policies)
- **User profiles** → user-profile-service (MongoDB)
- **Devices, SIMs, connectors** → resource-inventory-service
- **Subscription plans, limits** → subscription service
- **Notifications** → notification-service
- **Tenant access enforcement** → organisation-service CheckAccess gRPC

**Rule:** Never duplicate logic that has a canonical owner. Call the authoritative service.

## Multi-Tenancy and Access Control

**ALL tenant-scoped operations MUST:**
1. Extract user/org context from JWT (via go-kit/auth)
2. Call organisation-service CheckAccess gRPC to validate permissions
3. Only proceed if authorized

**Example:**
```go
// Get org from context
orgID, err := auth.GetOrganizationID(ctx)

// Check access via organisation-service
hasAccess, err := s.orgClient.CheckAccess(ctx, &org.CheckAccessRequest{
    OrganizationID: orgID,
    UserID:         userID,
    Resource:       "devices",
    Action:         "read",
})
```

## Frontend Structure

**Module organization (chirp-frontend/src):**
```
src/
├── modules/           # Feature modules (Devices, Gateways, RulesEngine, etc.)
├── entities/          # TypeScript domain models (26 files)
├── components/        # Reusable UI components
├── services/api/      # API clients (calls BFF only, NEVER microservices)
├── const/             # Constants (NEVER hardcode strings)
├── hooks/             # Custom React hooks
├── contexts/          # React Context providers
└── pages/             # Route pages
```

**API Integration:**
- Frontend calls ONLY BFF endpoints
- Use typed API clients in `services/api/`
- Use TanStack Query for data fetching
- Models defined in `entities/`

## Environment Setup

**Go services:**
```bash
# Copy appropriate .env file
cp .env.local .env      # Fully local (docker-compose for all deps)
cp .env.dev .env        # Remote dev (port-forward to cloud)
cp .env.example .env    # Custom config
```

**BFF local development:**
```bash
# Start all dependencies
docker compose up -d    # Postgres, Redis, NATS, Mosquitto, ChirpStack

# Run BFF
make build && ./build/bff
# Or: go run main.go
```

**BFF remote development:**
```bash
# Port-forward to dev environment
./port-forward-dev.sh   # Linux/macOS
.\port-forward-dev.ps1  # Windows

# Run BFF locally
go run main.go
```

## ChirpStack Integration

ChirpStack v4.4.2 is the LoRaWAN Network Server:
- Local URL: http://localhost:8089
- Default creds: admin/admin
- Region: eu868
- BFF integrates ChirpStack APIs into unified endpoints

## Shared Libraries

[**go-kit/**](../go-kit/) (import these for cross-cutting concerns):
- `go-kit/auth` - JWT validation, context propagation
- `go-kit/errs` - Structured error handling
- `go-kit/jwt-key-selector` - JWKS/PEM key management

[**ui-kit/**](../ui-kit/) (NPM package `@chirpwireless/ui-kit`):
- Shared React components
- Design tokens, CSS variables
- Import to ensure consistent UX across apps

## Code Review Checklist

Before committing, verify:

- [ ] Layer separation correct (Domain → Service → Infrastructure → Delivery)
- [ ] Interfaces defined in service layer (consumer-side)
- [ ] Errors wrapped with `fmt.Errorf("context: %w", err)`
- [ ] Using `slog.InfoContext/ErrorContext` with context
- [ ] Context passed to all I/O operations
- [ ] NO hardcoded values (use constants, config, feature flags)
- [ ] NO business logic in handlers or repositories
- [ ] Domain layer has NO external dependencies
- [ ] Dependencies injected through interfaces
- [ ] Single Source of Truth respected (check [`singletruth.md`](./singletruth.md))
- [ ] Tenant isolation enforced (organisation-service CheckAccess)
- [ ] Tests use mocks, not real infrastructure

## Testing Strategy

**Go:**
- Unit tests: `*_test.go` next to source, using testify + mocks
- Integration tests: `app/tests/` directory (resource-inventory-service example)
- Manual tests: `app/tests/manual/` with docker-compose for 3rd party + port-forward for internal services (see [`agent_testing_manual.md`](./agent_testing_manual.md))
- Table-driven tests for multiple scenarios

**Frontend:**
- Jest + React Testing Library
- Config: [`jest.config.js`](../chirp-frontend/jest.config.js)

## Deployment

**Build:**
- Each service has a Dockerfile (runtime base varies: Alpine for most APIs, Ubuntu for BFF)
- Binaries are built in the CI/CD pipeline and copied into the runtime image; set `CGO_ENABLED=0` where static linking is required

**CI/CD:**
- GitHub Actions: [`.github/workflows/`](../go-boilerplate/.github/workflows/) (see go-boilerplate for example)
- Reusable workflows from `chirpwireless/reusable-github-actions`

**Kubernetes:**
- Helmfile templates: [`deploy/helmfile.yaml.gotmpl`](../go-boilerplate/deploy/helmfile.yaml.gotmpl) (see go-boilerplate for example)
- Environment-specific values: [`deploy/values/{env}.yaml`](../go-boilerplate/deploy/values/) (see go-boilerplate for example)
- Environments: dev, staging, prod, kiloiot-dev, kiloiot-staging, kiloiot-prod
- **Shared Helm chart**: [`reusable-helm-chart/`](../reusable-helm-chart/) — all services use this chart via helmfile; supports deployment, HPA, ingress, ExternalSecrets (Vault), Liquibase DB migrations (pre-install Job), NATS JetStream Stream/Consumer CRDs, ServiceMonitor, RBAC, CronJob, MongoDB, PVC, HTTPRoute, and Envoy Gateway policies. Published at `helm repo add chirpwireless https://chirpwireless.github.io/reusable-helm-chart`.

## Key Technologies

**Backend:**
- Go 1.23-1.24, Gin, gRPC
- PostgreSQL, MongoDB, Redis
- OpenTelemetry, NATS, MQTT
- Stripe, Zitadel (auth), Supersend (notifications)

**Frontend:**
- React 18.3.1, TypeScript 5.6, Vite 7.1
- Material-UI v5, TanStack Query, React Hook Form
- Mapbox GL, Nivo charts, wagmi (Web3)

## Remember

1. **Follow [`LLM_CODING_PROMPT.md`](./LLM_CODING_PROMPT.md) religiously** - It defines Clean Architecture rules
2. **Check [`singletruth.md`](./singletruth.md) before adding logic** - Don't duplicate canonical data
3. **Check [`chirptree.md`](./chirptree.md) for structural placement** - Understand where components live
4. **NO hardcoded values** - This is explicitly forbidden
5. **Consumer-side interfaces** - Define in service layer, implement in infrastructure
6. **Always use context** - For tracing, cancellation, and request-scoped values
7. **Wrap all errors** - With meaningful context at each layer
8. **Test with mocks** - Never depend on real databases or external services in unit tests
