# Chirp Platform Structural Tree

```
Fullchirp/ – Monorepo for Chirp IoT platform; Clean Architecture standards captured in LLM_CODING_PROMPT.md
├── LLM_CODING_PROMPT.md – Canonical engineering contract (SOLID, layering, error handling rules) every service follows
├── go-kit/ – Shared Go modules reused by all backends (consumer-side interfaces, Fx wiring, auth helpers)
│   ├── auth/ – JWT parsing, context propagation, and gRPC interceptors for Zitadel-authenticated calls
│   ├── errs/ – Structured error helpers plus grpc adapters that keep error semantics consistent
│   ├── jwt-key-selector/ – JWKS/PEM key selection utility so services use the same signing source of truth
│   └── uber-fx/ – Opinionated Fx modules (grpc, metrics, postgres, redis, telemetry, temporal, test-suite) to bootstrap services the same way
├── ui-kit/ – Shared React/Vite component library consumed by the frontend
│   ├── src/lib/ – Headless + styled widgets (tables, dialogs, charts, map, toast, wallet banner, etc.) for uniform UX
│   ├── src/styles/ – Theme tokens, mixins, and CSS variables that define the design system palette/spacing
│   └── src/helpers & hooks – Light utility layer (i18n helpers, form hooks) used by consumer apps
├── chirp-frontend/ – Main SPA (Vite + React) for dashboards, automation, and device control
│   ├── src/entities/ – TypeScript source of truth for domain models (devices, sims, subscriptions, payments, workflows)
│   ├── src/const/ – Centralized constants (device types, URLs, wallet copy, widget definitions) imported across modules
│   ├── src/locales/ – i18n resource bundles (JSON) powering multilingual UI copy
│   ├── src/services/api/ – API clients for BFF + microservices (auth, map, blockchain, subscriptions, etc.)
│   ├── src/modules/ – Feature bundles (Devices, Gateways, RulesEngine, Kage, Subscriptions, Wallet, etc.) wired into router/pages
│   ├── src/features/ & components/ – Reusable UI logic (forms, overlays, filters) that compose modules
│   └── src/ui/ & layouts/ – Layout chrome, theme switch, skeletons, loaders shared across the app
├── bff/ – Backend-For-Frontend that federates ChirpStack, automation engines, NATS, and internal services behind a unified API
│   ├── main.go & pkg/settings – Server entrypoint plus env/config loaders
│   ├── pkg/api/ – HTTP routing + Swagger definitions surfacing BFF endpoints
│   ├── pkg/auth/ – Auth middleware, token validation, and context user extraction
│   ├── pkg/integration/ – Clients for every downstream (account mgmt, resource inventory, notification, subscription, automation, MQTT, Zammad, etc.)
│   ├── pkg/service/ – Orchestrated use-cases that stitch integrations together
│   └── pkg/util/ – Cross-cutting helpers (MQTT session mgmt, caching, telemetry)
├── account-management-service/ – Handles registration, authentication, and role management via gRPC/HTTP, backed by Zitadel + user profile
│   └── app/
│       ├── cmd/ – Service entrypoints for HTTP + gRPC servers
│       ├── docs/ – Swagger/OpenAPI specs backing the HTTP transport
│       ├── internal/
│       │   ├── bootstrap/ – Wiring of config, logging, tracing, Zitadel adapters
│       │   ├── core/account/ – Account domain models and primary business logic
│       │   ├── integration/ – Clients for Zitadel and user-profile service
│       │   └── transport/ – HTTP and gRPC handlers + interceptors
│       └── pkg/proto/ – Buf-managed protobuf specs plus generated Go stubs
├── organisation-service/ – CRUD + policies for organizations, members, roles, invitations
│   ├── app/migrations/ – Liquibase changelogs for organization/member schema
│   ├── app/cmd/ – Entrypoints for the gRPC server and background workers
│   ├── app/api/ – Protobuf definitions plus generated gRPC stubs
│   ├── app/abac_model.conf – Casbin ABAC model used in enforcement decisions
│   └── app/internal/
│       ├── domain/ – Organization aggregates (members, predefined roles, ownership invites)
│       ├── repository/ – Data access layer (Casbin-backed policies, membership persistence, invitations)
│       ├── service & usecase/ – Access-control checks, invite + ownership workflows, Casbin policy hydration
│       ├── delivery/ – gRPC transport adapters
│       └── infrastructure/ – Config + external integrations (DB, Zitadel tokens)
├── user-profile-service/ – Mongo-backed profile, preferences, wallets, and notification caps
│   ├── pkg/domain/ – Domain structs for users and preferences
│   ├── pkg/repository/ – Mongo repositories encapsulating persistence rules
│   ├── pkg/service/ – gRPC use-cases (profile CRUD, EULA, wallet ops)
│   ├── pkg/api & proto/ – gRPC definitions surfaced to callers
│   └── pkg/notificationservice & settings – Clients + config for Notification svc
├── resource-inventory-service/ – Device, SIM, connector & game item registry plus access control
│   ├── migrations/ – Liquibase changelogs for Postgres schema
│   ├── tests/ – Integration + contract suites validating device workflows
│   └── app/
│       ├── cmd/ – Binary entrypoints (API server, migration runner, background jobs)
│       ├── pkg/ – Generated proto clients shared with other services
│       └── internal/
│           ├── domain/ – Canonical resource models (device, sim_card, game_item, organization access)
│           ├── repository/ – Persistence interfaces over Postgres
│           ├── usecase/ – Device/sim workflows, dashboards, assignment batches
│           ├── transport/ – gRPC/HTTP delivery exposing inventory APIs
│           ├── feature/ – Feature-flag toggles (subscription limits, org resolution)
│           ├── integration/organization – gRPC client for organisation-service access checks to enforce tenant isolation
│           └── bootstrap/config – Wiring of DB, Zitadel auth, and other external service clients
├── notification-service/ – NATS-driven notification router integrated with Supersend templates
│   ├── templates/ – Supersend-compatible default templates for alerts and workflows
│   ├── deploy/ & docker-compose.yaml – Local stack + Kubernetes manifests
│   ├── app/migrations/ – SQL migrations for notification history, templates, quotas
│   └── app/
│       ├── cmd/ – Entrypoints for the notification API server and worker consumers
│       ├── pkg/ – Shared proto definitions plus helper clients
│       └── internal/
│           ├── domain/ – Templates, notification payloads, histories, verification codes
│           ├── repository/ – Storage for template overrides, history logs, quotas
│           ├── service/ – Dispatch logic (email/SMS), quota enforcement, Supersend orchestration
│           ├── auth & utils – Token validation + helper routines
│           ├── integration/ – Supersend + NATS adapters
│           └── transport/ – gRPC endpoints and background consumers
├── automation-service/ – Temporal + NATS rule engine executing user-defined workflows via Gorules ZEN
│   ├── app/cmd/ – Service entrypoint wiring Fx + env load
│   ├── app/migrations/ – Liquibase SQL for rule/action tables and metadata columns
│   ├── app/internal/
│   │   ├── bootstrap/ – Fx modules (config, NATS, Temporal workers, feature flags, downstream clients)
│   │   ├── core/ – Domain logic: rule, ruledefinition, ruletimer, action, condition, workflow, scheduler, access
│   │   ├── transport/ – gRPC services (rule, action, workflow, ruletimer, v2 rule) plus NATS consumer for device events
│   │   ├── integration/ – Clients to inventory, organisation, subscription, user-profile with token handling
│   │   ├── feature/ – Feature toggles (subscription limits, org resolution, remain-true-for)
│   │   └── usecase/assign_rule_orgs – Organization assignment workflows
│   ├── app/pkg/ – Buf proto (v1/v2) for rule/action/ruletimer/workflow and generated Go stubs
│   ├── app/tests/ – Integration suites (gRPC, NATS, Temporal) with mocked downstreams
│   ├── app/examples/nats-pub/ – Sample NATS publisher for device events
│   └── deploy/ & docker-compose.yaml – Local stack and manifests
├── rule-modeler-engine/ – Rule design-time service (definitions, versions, BPMN diagrams) with collaborative WebSocket editing, version control, and locking
│   ├── app/api/grpc/ – Protobuf definitions and generated gRPC stubs (client-only, no inbound gRPC services)
│   ├── app/cmd/server/ – Service entrypoint
│   ├── app/migrations/ – Liquibase migrations for rule_definition, rule_version, rule_diagram, and outbox tables
│   ├── app/internal/
│   │   ├── app/ – Composition root (manual DI wiring)
│   │   ├── auth/ – Auth/context helpers (JWT user extraction, token propagation)
│   │   ├── clients/ – gRPC clients (organisation, subscription, user-profile with shared interceptors/errors)
│   │   ├── delivery/rest/ – Gin REST handlers for rule definitions, versions, builds, deployment (Swagger-documented)
│   │   ├── delivery/websocket/ – WebSocket handler for collaborative locking (lock, unlock, heartbeat, auto-unlock on disconnect)
│   │   ├── delivery/grpc/ – gRPC server setup and interceptors
│   │   ├── domain/ – Rule definition, rule version, rule diagram, build, deployment domain models with BPMN XML validation
│   │   ├── repository/postgres/ – Postgres adapters for rule definitions, versions, and diagrams
│   │   ├── usecase/ – 27 use cases: rule CRUD, clone, trash/restore, lock/unlock/heartbeat/force-unlock, version list/rename/restore, save, BPMN validate, build and deploy stubs
│   │   └── infrastructure/ – Config (cleanenv), DB (sqlx), logger (slog), NATS JetStream, Tx manager
│   ├── app/configs/ – Service config examples (YAML for local, dev)
│   └── app/docs/ – Auto-generated Swagger documentation
├── event-service/ – Event ingestion & aggregation (Gin HTTP, NATS JetStream, TimescaleDB) with event/calendar APIs and data normalization
│   ├── app/cmd/ – Cobra entrypoint loading env and starting the app
│   ├── app/migrations/ – Liquibase SQL for events schema, devlog table/indexes, daily summary materialized view
│   ├── app/internal/
│   │   ├── bootstrap/ – Wires config, Postgres/Timescale, NATS JetStream (stream creation), event producer, resource-inventory + subscription clients, metrics server
│   │   ├── transport/http/ – Gin router, Swagger-ready handlers (events, calendar), health/metrics endpoints
│   │   ├── repository/ – storage/ Timescale event & calendar repos with insert buffer; normalized/ optional normalized stores
│   │   ├── service/ – Event and calendar services plus cleanup routines
│   │   ├── integration/ – Clients for resource-inventory, subscription, data normalizer; NATS producer
│   │   ├── config/ & feature/ – Feature toggles (normalizer, subscription limits, read-only) and service settings
│   │   └── domain/ – Core entities and interfaces for events, calendars, inventory, subscription, normalizer
│   ├── app/feature/ – Feature flag helpers (normalizer, subscription limits)
│   ├── app/utiles/ – Auth setup utilities
│   └── deploy/ & docker-compose.yml – Local stack (PG/Timescale, NATS, service)
├── data-credits-service/ – gRPC service managing data credits balances and payments (Sui blockchain + NowPayments IPN)
│   ├── app/cmd/service/ – gRPC entrypoint wiring JWT auth, reflection, health probes
│   ├── app/cmd/ipn_test/ – Helper for testing payment notifications
│   ├── app/internal/
│   │   ├── config/ – Service configuration (DB, JWT, Sui RPC, NowPayments)
│   │   ├── infrastructure/db/ – Postgres accessors for balance, balancelog, payments; Liquibase migrations
│   │   ├── service/ – Business logic for data credits, fees, payments, transactions; exchanger/ and nowpayments/ clients; transactions/ for Sui execution
│   │   ├── transport/grpc/ – gRPC servers for DataCredits and Payments APIs with tests/mocks
│   │   └── domain/ – Entities and interfaces for balances, payments, exchanges
│   ├── app/pkg/proto/ – Protobuf definitions + generated stubs for data credits and payments
│   ├── app/pkg/auth & helpers – JWT validation (BFF TOKEN_SECRET) and shared gRPC/config helpers
│   ├── app/pkg/docker-entrypoint-initdb.d/ – DB bootstrap SQL (role/db creation)
│   └── deploy/ & docker-compose.yml – Local stack (service + Postgres)
├── go-boilerplate/ – Template Go microservice (Clean/Hexagonal skeleton) for new services; not a production service
│   ├── app/cmd/server/ – Minimal entrypoint to start the template gRPC server
│   ├── app/internal/app/ – Composition root with manual DI wiring
│   ├── app/internal/domain/ – Sample domain entities/errors
│   ├── app/internal/usecase/ – “1 operation = 1 package” examples (user_create, user_get) with TxManager
│   ├── app/internal/repository/postgres/ – Postgres adapters using transaction getter pattern
│   ├── app/internal/clients/notification/ – Stub external client illustrating consumer-owned interfaces
│   ├── app/internal/messaging/ – Kafka publisher/consumer example for user events
│   ├── app/internal/delivery/grpc/ & delivery/kafka/ – Driving adapters for gRPC handlers and Kafka consumer
│   ├── app/internal/infrastructure/ – Config, logger (slog), DB, tx manager, Kafka plumbing
│   ├── app/api/grpc/ – Proto definitions + generated stubs
│   ├── app/migrations/ – Liquibase migrations used by the template
│   ├── app/configs/ – Example config (config.yaml.example)
│   └── deploy/ & docker-compose.yml – Local dev stack (Postgres, Kafka/Zookeeper, migrations, service)
├── subscription/ – Subscription lifecycle + Stripe integration plus HTTP webhook worker
│   ├── docker-entrypoint-initdb.d/ – SQL bootstraps for Postgres schema
│   ├── deploy/ & docker-compose.yml – Local orchestration + manifests
│   └── app/
│       ├── cmd/subscription & cmd/webhook – Separate binaries for gRPC API and Stripe webhook handler
│       ├── api/ – gRPC + HTTP surface (proto definitions, handlers)
│       ├── internal/
│       │   ├── domain/ – Checkout session, subscription, trial, rules, Stripe mapping entities
│       │   ├── service/ – Use-cases (plan upgrades, rule enforcement, validation)
│       │   ├── infrastructure/ – Stripe client, DB adapters, queue integrations
│       │   ├── delivery/ – gRPC + HTTP handlers, middleware
│       │   ├── feature/ – Flipt-based feature toggles
│       │   └── cache & util – Redis-based caches plus helper packages
│       └── pkg/ – Shared proto + helper code
├── rules-engine-executor/ – Rule execution runtime service (boilerplate-based skeleton) for executing finalized rules from rule-modeler-engine
│   ├── app/cmd/server/ – Service entrypoint
│   ├── app/api/grpc/ – Protobuf definitions (UserService stub) and generated gRPC stubs
│   ├── app/migrations/ – Liquibase migrations for users and outbox tables (boilerplate schema)
│   ├── app/internal/
│   │   ├── app/ – Composition root (manual DI wiring)
│   │   ├── domain/ – Domain entities (User stub) and error types
│   │   ├── usecase/ – Use cases: user_create, user_get (boilerplate examples demonstrating patterns)
│   │   ├── repository/postgres/ – Postgres adapters with sqlx and squirrel
│   │   ├── delivery/grpc/ – gRPC server, handlers, and interceptors
│   │   ├── delivery/nats/ – NATS JetStream consumer for event processing
│   │   ├── clients/notification/ – Notification service client (stub)
│   │   ├── messaging/user/ – NATS event publisher with at-least-once delivery
│   │   └── infrastructure/ – Config (cleanenv), DB (sqlx), logger (slog), NATS JetStream, Tx manager
│   ├── app/configs/ – Service config examples
│   └── deploy/ – Helm values for dev, staging, kiloiot environments
├── alarms-service/ – Alarm lifecycle management and notification orchestration for the IoT platform; Clean Architecture with two processes from a single Docker image
│   ├── app/migrations/ – SQL migrations for alarm, inbox, dispatch, notification tables
│   ├── app/config/ – Service configuration (config.yaml.example, .env.example, seed-example.json)
│   ├── app/internal/
│   │   ├── alarms/                    # Alarm domain module
│   │   │   ├── domain/                # Alarm entities, value objects, fingerprinting, suppression
│   │   │   ├── usecase/               # Alarm use cases (1 operation = 1 package: contract + usecase + test)
│   │   │   ├── repository/            # Alarm persistence (severity_policy, alarm_schedule, escalation_policy, alarm_definition, alarm_event, dispatch_state)
│   │   │   └── delivery/              # Alarm gRPC handlers (AlarmsService)
│   │   ├── notifications/             # Notification domain module
│   │   │   ├── domain/                # Notification entities, channel types (email/sms/push), verification
│   │   │   ├── service/               # DeliveryRequester (maps SendRequest → delivery_requests)
│   │   │   ├── repository/            # Notification persistence (delivery_requests, delivery_attempts, user_channels, verification, provider_configs)
│   │   │   └── delivery/              # Notification consumers + gRPC handlers (NotificationChannelsService)
│   │   ├── shared/ports/              # Cross-module interfaces (DeliveryRequester, DeliveryResultHandler)
│   │   ├── app/grpc/                  # gRPC composition root (DI wiring for gRPC server process)
│   │   ├── app/worker/                # Worker composition root (DI wiring for NATS consumer process)
│   │   ├── domain/                    # Shared domain (errors)
│   │   ├── infrastructure/            # DB, NATS JetStream, gRPC, config (cleanenv), logger (slog), Tx manager
│   │   └── workers/inbox/             # Inbox pattern runner: claim → dispatch → handler → mark processed/failed; retry + recover stuck + fail stuck
│   ├── app/test/integration/          # 225+ integration tests across 9 suites (e2e, trigger, dispatch, resolve, inbox, alarms_repo, notifications_repo, grpc_definitions, grpc_events)
│   ├── deploy/                        # Helmfile producing two releases: alarms-grpc-service + alarms-worker
│   │   └── values/{dev,staging,prod,kiloiot-dev,kiloiot-staging,kiloiot-prod}/ – Per-env Helm values
│   ├── docs/alarms/                   # Architecture, API contracts, inbox/outbox patterns
│   ├── Dockerfile                     # Single image; binary selected via CMD (grpc-server or worker)
│   └── Makefile                       # build, test, test-integration, lint, proto, generate-mocks, dev-up/down, migrate
└── Misc deploy/ directories – Helm/manifest definitions for each microservice plus docker-compose stacks for local dev
```
