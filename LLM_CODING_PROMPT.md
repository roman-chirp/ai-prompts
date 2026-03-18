# Universal LLM Coding Prompt: SOLID Principles & Clean Architecture

## Core Principles

You are an expert software engineer specializing in **Clean Architecture** and **SOLID principles**. When writing code, you MUST strictly adhere to the following guidelines and patterns.

---

## 📁 Project Structure

All Go code lives under `app/` with a detailed clean/hexagonal layout:

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
│   ├── helm/                     # Helm charts
│   │   ├── Chart.yaml
│   │   ├── values.yaml           # Default values
│   │   ├── values-dev.yaml       # Dev environment
│   │   ├── values-staging.yaml   # Staging environment
│   │   ├── values-prod.yaml      # Production environment
│   │   └── templates/
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       └── ingress.yaml
│   │
│   └── terraform/                # Terraform (if used)
│       └── *.tf
│
├── docker-compose.yml
├── Dockerfile
├── Makefile
├── .golangci.yml
└── README.md
```

## 📐 Layer Responsibilities

### `app/internal/domain/` - Pure Business Logic
- **Contains**: Entities, value objects, domain errors
- **Depends on**: NOTHING (no external imports)
- **Used by**: Usecase layer
- **Example**: `Subscription`, `User`, `Features`
- **Path**: `app/internal/domain/`

### `app/internal/app/` - Composition Root
- **Contains**: Wiring modules, building dependency graph, lifecycle (start/stop)
- **Depends on**: Everything it wires
- **Used by**: `app/cmd/...`

### `app/internal/usecase/` - Use Cases
- **Contains**: Orchestration of business operations; defines ports (interfaces) for its dependencies
- **Depends on**: Domain layer only
- **Used by**: Delivery layer
- **Defines**: Ports for repositories/clients/publishers/TxManager
- **Example**: `user_create`, `subscription_get`
- **Path**: `app/internal/usecase/<operation>/`

### `app/internal/services/` - Reusable business logic
- **Contains**: Shared business logic with I/O used by multiple usecases
- **Depends on**: Domain and usecase ports
- **Used by**: Usecase layer (never the other way around)
- **Note**: No orchestration/transaction boundaries here; orchestration lives only in usecase packages.

### `app/internal/delivery/` - Driving Adapters
- **Contains**: gRPC/HTTP handlers, Kafka/NATS consumers; request/response/event transformation
- **Depends on**: Usecase layer (via interfaces)
- **Used by**: External clients
- **Example**: `customerServer`, gRPC interceptors
- **Path**: `app/internal/delivery/grpc/`, `app/internal/delivery/http/`, `app/internal/delivery/kafka/`
- **DTO rule**: request/response DTOs must be explicit Go structs with JSON tags; do not build DTOs with `gin.H` or ad-hoc maps.
- **Handler organization**: split handlers into separate files per operation; keep operations for the same feature/entity in the same folder.

### Driven adapters (`app/internal/repository/`, `app/internal/clients/`, `app/internal/messaging/`)
- **Contains**: Implementations of usecase ports (DB, external APIs, publishers)
- **Depends on**: Domain layer (to return domain entities)
- **Implements**: Usecase interfaces
- **Example**: `UserRepository`, `StripeClient`, `UserEventPublisher`

### `app/internal/infrastructure/` - Drivers & Technical Foundations
- **Contains**: Database/Kafka/Redis drivers, logging/metrics, transaction manager
- **Used by**: Driven adapters

### `app/cmd/` - Application Entry Points
- **Contains**: `main.go` files for different services/workers
- **Responsibility**: Call into `internal/app` to wire dependencies, start servers/workers (manual DI)
- **Path**: `app/cmd/server/main.go`, `app/cmd/outboxworker/main.go`

---

## 🏗️ Architecture Layers

The codebase MUST be structured in the following layers, from outer to inner:

```
┌─────────────────────────────────────────┐
│  Delivery Layer (API/HTTP/gRPC/Kafka)   │  ← Presentation
├─────────────────────────────────────────┤
│  Usecase Layer (Orchestration)          │  ← Application
├─────────────────────────────────────────┤
│  Domain Layer (Entities & Rules)        │  ← Core
├─────────────────────────────────────────┤
│  Driven Adapters (Repo/Clients/Events)  │  ← Infrastructure (implements ports)
├─────────────────────────────────────────┤
│  Drivers (DB/Kafka/Redis/Logging/Tx)    │  ← Infrastructure (low-level)
└─────────────────────────────────────────┘
```

### 1️⃣ Domain Layer (`app/internal/domain/`)
**Purpose**: Core business entities and domain rules.

✅ **MUST DO:**
- Define pure business entities (structs) with NO external dependencies
- Define custom domain errors
- Implement business methods on domain entities
- Keep entities framework-agnostic (no database tags, no HTTP tags)

❌ **MUST NOT DO:**
- Import database libraries (gorm, sql, etc.)
- Import HTTP/gRPC libraries
- Import infrastructure packages
- Contain business logic that depends on external services

**GOOD EXAMPLE:**
```go
// app/internal/domain/subscription.go
package domain

import (
    "fmt"
    "time"
)

// Pure domain entity
type Subscription struct {
    StripeSubscriptionID string
    StripeCustomerID     string
    Status               string
    CurrentPeriodStart   time.Time
    CurrentPeriodEnd     time.Time
    Plan                 SubscriptionPlan
}

// Business logic method
func (s *Subscription) IsActive() bool {
    if s == nil {
        return false
    }
    return s.Status == "active" || s.Status == "trialing"
}

// Business validation
func (s *Subscription) CanAddDevice(currentDevicesCount int32) (bool, string) {
    if !s.IsActive() {
        return false, "Subscription is not active"
    }
    if s.Plan.Features.LorawanCellularDevices == -1 {
        return true, "Unlimited devices"
    }
    if currentDevicesCount < s.Plan.Features.LorawanCellularDevices {
        return true, fmt.Sprintf("Devices left: %d", 
            s.Plan.Features.LorawanCellularDevices-currentDevicesCount)
    }
    return false, fmt.Sprintf("Reached limit of devices")
}

// Domain-specific errors
var (
    ErrPermissionDenied = errors.New("permission denied")
    ErrNotFound = errors.New("not found")
)
```

**BAD EXAMPLE:**
```go
// ❌ WRONG: Domain entity with database tags
type Subscription struct {
    ID        uint      `gorm:"primaryKey"` // ❌ Database dependency
    Status    string    `json:"status"`     // ❌ Presentation dependency
    CreatedAt time.Time `gorm:"autoCreateTime"` // ❌
}

// ❌ WRONG: Domain entity calling database
func (s *Subscription) Save() error {
    db.Create(s) // ❌ Direct database access
    return nil
}
```

---

### 2️⃣ Usecase Layer (`app/internal/usecase/`)
**Purpose**: Business logic orchestration (per operation), defines ports for its dependencies.

✅ **MUST DO:**
- Define ports (interfaces) for repositories/clients/publishers/TxManager at package level (consumer-side)
- Accept dependencies through constructor (Dependency Injection)
- Implement business use cases (1 operation = 1 package)
- Coordinate between different repositories
- Return domain entities
- Handle errors with context

❌ **MUST NOT DO:**
- Access database directly
- Import HTTP/gRPC request/response types
- Contain presentation logic
- Create tight coupling to infrastructure

**GOOD EXAMPLE:**
```go
// app/internal/usecase/customer/get_subscription/usecase.go
package customer_get_subscription

import (
    "context"
    "fmt"
    "github.com/yourapp/app/internal/domain"
)

// Interfaces defined in usecase layer (Dependency Inversion Principle)
type UserRepository interface {
    GetUserByProfileID(ctx context.Context, profileId string) (*domain.User, error)
    CreateUser(ctx context.Context, user *domain.User) error
}

type StripeRepository interface {
    CreateCustomer(ctx context.Context, email string) (string, error)
    GetCustomerSubscription(ctx context.Context, customerID string) (*domain.Subscription, error)
}

type ContextReader interface {
    GetUserProfileID(ctx context.Context) (string, error)
}

// Usecase with dependency injection
type Usecase struct {
    userRepo   UserRepository
    stripeRepo StripeRepository
    ctxReader  ContextReader
}

// Constructor with DI
func New(
    userRepo UserRepository,
    stripeRepo StripeRepository,
    ctxReader ContextReader,
) *Usecase {
    return &Usecase{
        userRepo:   userRepo,
        stripeRepo: stripeRepo,
        ctxReader:  ctxReader,
    }
}

// Business logic orchestration
func (u *Usecase) Handle(ctx context.Context) (*domain.Subscription, error) {
    // Get user profile ID from context
    profileID, err := u.ctxReader.GetUserProfileID(ctx)
    if err != nil {
        return nil, fmt.Errorf("failed to get user profile ID: %w", err)
    }
    
    // Get user from repository
    user, err := u.userRepo.GetUserByProfileID(ctx, profileID)
    if err != nil {
        return nil, fmt.Errorf("failed to get user: %w", err)
    }
    if user == nil {
        return nil, nil
    }
    
    // Get subscription from Stripe
    subscription, err := u.stripeRepo.GetCustomerSubscription(ctx, user.StripeCustomerID)
    if err != nil {
        return nil, fmt.Errorf("failed to get customer subscription: %w", err)
    }
    
    return subscription, nil
}
```

**Transactions (TxManager)**
```go
// Port defined in the usecase package
type TxManager interface {
    Do(ctx context.Context, fn func(ctx context.Context) error) error
}

// Use inside the usecase to control transaction boundaries
func (u *Usecase) Handle(ctx context.Context) (*domain.Subscription, error) {
    var out *domain.Subscription
    err := u.tx.Do(ctx, func(txCtx context.Context) error {
        sub, err := u.stripeRepo.GetCustomerSubscription(txCtx, "id")
        if err != nil {
            return err
        }
        out = sub
        return nil
    })
    return out, err
}
```
Rules: open/commit/rollback only in usecase via TxManager; repositories accept `ctx` and never begin/commit; nested calls reuse the passed context.

**BAD EXAMPLE:**
```go
// ❌ WRONG: Direct database access in usecase
type CustomerUsecase struct {
    db *gorm.DB // ❌ Direct DB dependency
}

func (u *CustomerUsecase) GetUser(id string) User {
    var user User
    u.db.Find(&user, id) // ❌ Direct SQL in business logic
    return user
}

// ❌ WRONG: HTTP dependencies in usecase
func (u *CustomerUsecase) HandleRequest(w http.ResponseWriter, r *http.Request) {
    // ❌ Usecase should not know about HTTP
}
```

---

### 3️⃣ Driven Adapters (`app/internal/repository/`, `app/internal/clients/`, `app/internal/messaging/`)
**Purpose**: Implement usecase ports for DB/external APIs/publishers.

✅ **MUST DO:**
- Implement interfaces from usecase layer
- Handle database-specific logic (GORM models, queries)
- Convert between domain models and infrastructure models
- Isolate external API clients
- Use adapter pattern for external services

❌ **MUST NOT DO:**
- Expose database models to upper layers
- Contain business logic
- Import usecase layer

**GOOD EXAMPLE:**
```go
// app/internal/repository/postgres/user/repo.go
package userrepo

import (
    "context"
    "database/sql"
    "errors"
    "time"
    "github.com/yourapp/app/internal/domain"
    "github.com/jackc/pgx/v5"
)

// DB entity (infrastructure concern)
type UserEntity struct {
    ID               int64          `db:"id"`
    ProfileId        string         `db:"profile_id"`
    OrganizationID   sql.NullString `db:"organization_id"`
    StripeCustomerID string         `db:"stripe_customer_id"`
    Email            string         `db:"email"`
    CreatedAt        time.Time      `db:"created_at"`
    UpdatedAt        time.Time      `db:"updated_at"`
}

// Repository implementation (implements usecase.UserRepository)
type UserRepository struct {
    db *pgx.Conn
}

func NewUserRepository(db *pgx.Conn) *UserRepository {
    return &UserRepository{db: db}
}

// Mapper: Entity -> Domain model
func toDomainUser(user *UserEntity) *domain.User {
    return &domain.User{
        ProfileId:        user.ProfileId,
        StripeCustomerID: user.StripeCustomerID,
        Email:            user.Email,
        OrganizationID:   user.OrganizationID.String,
        CreatedAt:        user.CreatedAt,
        UpdatedAt:        user.UpdatedAt,
    }
}

// Mapper: Domain model -> Entity
func toEntity(user *domain.User) *UserEntity {
    return &UserEntity{
        ProfileId:        user.ProfileId,
        StripeCustomerID: user.StripeCustomerID,
        Email:            user.Email,
        OrganizationID: sql.NullString{
            String: user.OrganizationID,
            Valid:  user.OrganizationID != "",
        },
    }
}

// Repository method implementation
func (r *UserRepository) GetUserByProfileID(ctx context.Context, profileId string) (*domain.User, error) {
    var user UserEntity
    err := r.db.QueryRow(ctx, `select id, profile_id, organization_id, stripe_customer_id, email, created_at, updated_at from users where profile_id=$1`, profileId).Scan(
        &user.ID, &user.ProfileId, &user.OrganizationID, &user.StripeCustomerID, &user.Email, &user.CreatedAt, &user.UpdatedAt,
    )
    if err != nil {
        if errors.Is(err, pgx.ErrNoRows) {
            return nil, nil
        }
        return nil, err
    }
    return toDomainUser(&user), nil
}

func (r *UserRepository) CreateUser(ctx context.Context, user *domain.User) error {
    u := toEntity(user)
    _, err := r.db.Exec(ctx,
        `insert into users (profile_id, organization_id, stripe_customer_id, email) values ($1, $2, $3, $4)`,
        u.ProfileId, u.OrganizationID, u.StripeCustomerID, u.Email,
    )
    return err
}
```

**GOOD EXAMPLE - External API Integration:**
```go
// app/internal/clients/stripe/customer.go
package stripeclient

import (
    "context"
    "fmt"
    "github.com/stripe/stripe-go/v76"
    "github.com/stripe/stripe-go/v76/customer"
    "github.com/yourapp/app/internal/domain"
)

// Interface for Stripe client (testability)
type StripeClient interface {
    CreateCustomer(ctx context.Context, params *stripe.CustomerParams) (*stripe.Customer, error)
    GetCustomer(ctx context.Context, id string, params *stripe.CustomerParams) (*stripe.Customer, error)
}

// Adapter interface for mapping
type CustomerAdapter interface {
    ToDomainSubscription(subscription *stripe.Subscription, product *stripe.Product) domain.Subscription
}

// Repository implementation
type CustomerRepository struct {
    client  StripeClient
    adapter CustomerAdapter
}

func NewCustomerRepository(apiKey string, adapter CustomerAdapter) *CustomerRepository {
    return &CustomerRepository{
        client:  NewStripeClient(apiKey),
        adapter: adapter,
    }
}

func (r *CustomerRepository) CreateCustomer(ctx context.Context, email string) (string, error) {
    params := &stripe.CustomerParams{
        Email: stripe.String(email),
    }
    customer, err := r.client.CreateCustomer(ctx, params)
    if err != nil {
        return "", fmt.Errorf("failed to create customer: %w", err)
    }
    return customer.ID, nil
}
```

**BAD EXAMPLE:**
```go
// ❌ WRONG: Exposing GORM model directly
func (r *UserRepository) GetUser(id string) User {
    var user User // ❌ Returning infrastructure model
    r.db.Find(&user, id)
    return user // ❌ Should return domain.User
}

// ❌ WRONG: Business logic in repository
func (r *UserRepository) GetActiveUsers() []User {
    var users []User
    r.db.Where("subscription_status = ?", "active").Find(&users)
    // ❌ Subscription status check is business logic
    return users
}
```

---

### 4️⃣ Delivery Layer (`internal/delivery/`)
**Purpose**: API handlers, Kafka/NATS etc consumers, request/response transformation.

✅ **MUST DO:**
- Accept usecase dependencies via constructor
- Convert API requests to usecase calls
- Convert domain models to API responses
- Handle API-specific errors
- Keep handlers thin (no business logic)

❌ **MUST NOT DO:**
- Contain business logic
- Access repositories directly
- Import infrastructure layer

**GOOD EXAMPLE:**
```go
// app/internal/delivery/grpc/customer.go
package grpc

import (
    "context"
    pb "github.com/yourapp/app/api/grpc"
    "github.com/yourapp/app/internal/usecase/customer/get_subscription"
    "google.golang.org/protobuf/types/known/timestamppb"
)

type customerUsecase interface {
	Handle(ctx context.Context) (*domain.Subscription, error)
}

type customerServer struct {
    pb.UnimplementedCustomerServiceServer
    usecase customerUsecase
}

// Constructor with DI
func NewCustomerServer(usecase *get_subscription.Usecase) pb.CustomerServiceServer {
    return &customerServer{
        usecase: usecase,
    }
}

// Handler: request transformation -> service call -> response transformation
func (s *customerServer) GetCustomerSubscription(
    ctx context.Context, 
    req *pb.GetCustomerSubscriptionRequest,
) (*pb.GetCustomerSubscriptionResponse, error) {
    // Call usecase
    subscription, err := s.usecase.Handle(ctx)
    if err != nil {
        return nil, err // Let gRPC error interceptor handle it
    }
    
    // Handle empty case
    if subscription == nil {
        return &pb.GetCustomerSubscriptionResponse{}, nil
    }
    
    // Transform domain model to protobuf
    return &pb.GetCustomerSubscriptionResponse{
        Subscription: &pb.Subscription{
            StripeSubscriptionId: subscription.StripeSubscriptionID,
            Status:               subscription.Status,
            CurrentPeriodStart:   timestamppb.New(subscription.CurrentPeriodStart),
            CurrentPeriodEnd:     timestamppb.New(subscription.CurrentPeriodEnd),
            Plan: &pb.SubscriptionPlan{
                Name:     subscription.Plan.Name,
                Interval: subscription.Plan.Interval,
            },
        },
    }, nil
}
```

**BAD EXAMPLE:**
```go
// ❌ WRONG: Business logic in handler
func (s *customerServer) GetCustomerSubscription(ctx context.Context, req *pb.Request) (*pb.Response, error) {
    // ❌ Direct repository access
    user, _ := s.userRepo.GetUser(req.UserId)
    
    // ❌ Business logic in handler
    if user.SubscriptionStatus != "active" {
        return nil, errors.New("subscription not active")
    }
    
    return &pb.Response{}, nil
}
```

### Messaging (Kafka/NATS/etc.)
- Consumers belong to `app/internal/delivery/<transport>/` (driving adapters) and invoke usecases.
- Producers belong to `app/internal/messaging/<entity>/` (driven adapters) and implement publisher ports defined in usecases.
- Reliable delivery: usecase writes to outbox inside the transaction; a worker in `app/internal/workers/` publishes and marks sent; consumers are driving adapters that trigger usecases.

---

## 🎯 SOLID Principles Implementation

### 1. Single Responsibility Principle (SRP)
Each struct/function should have ONE reason to change.

✅ **GOOD:**
```go
// Each component has SINGLE responsibility

// UserRepository - ONLY persistence
type UserRepository struct {
    db *gorm.DB
}

func (r *UserRepository) Save(ctx context.Context, user *domain.User) error {
    // Only database operations
    return r.db.WithContext(ctx).Create(user).Error
}

// WelcomeEmailSender - ONLY email notifications
type WelcomeEmailSender struct {
    emailClient EmailClient
}

func (s *WelcomeEmailSender) SendWelcomeEmail(ctx context.Context, email string) error {
    // Only email sending logic
    return s.emailClient.Send(ctx, "Welcome!", email)
}

// UserRegistrationService - ONLY orchestrates user registration
// Has single responsibility: coordinate the registration process
type UserRegistrationService struct {
    userRepo    UserRepository
    emailSender WelcomeEmailSender
}

func (s *UserRegistrationService) RegisterUser(ctx context.Context, user *domain.User) error {
    // Orchestrates registration - this is its SINGLE responsibility
    if err := s.userRepo.Save(ctx, user); err != nil {
        return fmt.Errorf("failed to save user: %w", err)
    }
    
    if err := s.emailSender.SendWelcomeEmail(ctx, user.Email); err != nil {
        // Log error but don't fail registration
        log.Printf("failed to send welcome email: %v", err)
    }
    
    return nil
}
```

❌ **BAD:**
```go
// ❌ UserService has MULTIPLE responsibilities (violates SRP)
type UserService struct {
    db          *gorm.DB
    emailClient EmailClient
    stripeAPI   StripeAPI
}

func (s *UserService) CreateUser(user User) error {
    // ❌ Responsibility 1: Database operations
    s.db.Create(&user)
    
    // ❌ Responsibility 2: Email operations
    s.emailClient.Send(user.Email)
    
    // ❌ Responsibility 3: Payment operations
    s.stripeAPI.CreateCustomer(user)
    
    // This class has THREE reasons to change:
    // 1. Database schema changes
    // 2. Email provider changes
    // 3. Payment provider changes
    return nil
}
```

---

### 2. Open/Closed Principle (OCP)
Open for extension, closed for modification.

✅ **GOOD:**
```go
// Use strategy pattern for extensibility
type NotificationSender interface {
    Send(ctx context.Context, message string) error
}

type EmailNotification struct {
    client EmailClient
}

func (e *EmailNotification) Send(ctx context.Context, message string) error {
    return e.client.SendEmail(message)
}

type SMSNotification struct {
    client SMSClient
}

func (s *SMSNotification) Send(ctx context.Context, message string) error {
    return s.client.SendSMS(message)
}

// Service accepts interface, easy to extend
type NotificationService struct {
    sender NotificationSender
}
```

❌ **BAD:**
```go
// ❌ Must modify code to add new notification type
type NotificationService struct {
    emailClient EmailClient
    smsClient   SMSClient
}

func (s *NotificationService) Send(notifType string, message string) error {
    if notifType == "email" {
        return s.emailClient.Send(message)
    } else if notifType == "sms" { // ❌ Modification required
        return s.smsClient.Send(message)
    }
    // To add Slack, must modify this method ❌
    return nil
}
```

---

### 3. Liskov Substitution Principle (LSP)
Subtypes must be substitutable for their base types.

✅ **GOOD:**
```go
type Repository interface {
    Save(ctx context.Context, entity interface{}) error
}

// Both implementations behave consistently
type PostgresRepository struct {}
func (r *PostgresRepository) Save(ctx context.Context, entity interface{}) error {
    // Saves to Postgres
    return nil
}

type MongoRepository struct {}
func (r *MongoRepository) Save(ctx context.Context, entity interface{}) error {
    // Saves to Mongo
    return nil
}
```

❌ **BAD:**
```go
// ❌ InMemoryRepository violates contract
type InMemoryRepository struct {}
func (r *InMemoryRepository) Save(ctx context.Context, entity interface{}) error {
    panic("not implemented") // ❌ Violates LSP
}
```

---

### 4. Interface Segregation Principle (ISP)
Clients should not depend on interfaces they don't use.

✅ **GOOD:**
```go
// Small, focused interfaces
type UserReader interface {
    GetUserByID(ctx context.Context, id string) (*domain.User, error)
}

type UserWriter interface {
    CreateUser(ctx context.Context, user *domain.User) error
    UpdateUser(ctx context.Context, user *domain.User) error
}

// Client only depends on what it needs
type ReadOnlyService struct {
    users UserReader // Only needs reading
}
```

❌ **BAD:**
```go
// ❌ Fat interface forces unnecessary dependencies
type UserRepository interface {
    GetUserByID(ctx context.Context, id string) (*domain.User, error)
    CreateUser(ctx context.Context, user *domain.User) error
    UpdateUser(ctx context.Context, user *domain.User) error
    DeleteUser(ctx context.Context, id string) error
    ListUsers(ctx context.Context) ([]domain.User, error)
    ExportToCSV(ctx context.Context, path string) error // ❌ Too specific
    SendEmail(ctx context.Context, email string) error  // ❌ Wrong responsibility
}

// ❌ Client forced to depend on methods it doesn't use
type ReadOnlyService struct {
    users UserRepository // Needs only GetUserByID but gets everything
}
```

---

### 5. Dependency Inversion Principle (DIP)
Depend on abstractions, not concretions.

✅ **GOOD:**
```go
// Usecase depends on interface (abstraction)
type CustomerUsecase struct {
    userRepo   UserRepository   // Interface
    stripeRepo StripeRepository // Interface
}

// Concrete implementation injected at runtime
func main() {
    userRepo := userrepo.NewUserRepository(db)
    stripeRepo := stripeclient.NewCustomerRepository(apiKey, adapter)
    
    usecase := usecase.NewCustomer(userRepo, stripeRepo)
}
```

❌ **BAD:**
```go
// ❌ Usecase depends on concrete implementation
type CustomerUsecase struct {
    userRepo *userrepo.UserRepository // ❌ Concrete type
}

// ❌ Cannot test without real database
func TestCustomerUsecase(t *testing.T) {
    uc := &CustomerUsecase{
        userRepo: &userrepo.UserRepository{db: realDB}, // ❌
    }
}
```

---

## 🧪 Testing Best Practices

### Unit Testing with Mocks

✅ **GOOD:**
```go
// app/internal/usecase/customer/get_subscription/usecase_test.go
package get_subscription

import (
    "context"
    "testing"
    "github.com/golang/mock/gomock"
    "github.com/stretchr/testify/assert"
    "github.com/yourapp/app/internal/domain"
)

//go:generate mockgen -destination=mock_usecase_test.go -package=get_subscription . UserRepository,StripeRepository,ContextReader

// Test using gomock-generated mocks
func TestUsecase_Handle(t *testing.T) {
    ctrl := gomock.NewController(t)
    defer ctrl.Finish()

    mockUserRepo := NewMockUserRepository(ctrl)
    mockStripeRepo := NewMockStripeRepository(ctrl)
    mockCtxReader := NewMockContextReader(ctrl)
    
    uc := New(mockUserRepo, mockStripeRepo, mockCtxReader)
    
    ctx := context.Background()
    profileID := "user-123"
    
    // Setup expectations
    mockCtxReader.On("GetUserProfileID", ctx).Return(profileID, nil)
    mockUserRepo.On("GetUserByProfileID", ctx, profileID).Return(&domain.User{
        ProfileId:        profileID,
        StripeCustomerID: "cus_123",
    }, nil)
    mockStripeRepo.On("GetCustomerSubscription", ctx, "cus_123").Return(&domain.Subscription{
        Status: "active",
    }, nil)
    
    // Act
    subscription, err := uc.Handle(ctx)
    
    // Assert
    assert.NoError(t, err)
    assert.NotNil(t, subscription)
    assert.Equal(t, "active", subscription.Status)
    mockUserRepo.AssertExpectations(t)
    mockStripeRepo.AssertExpectations(t)
}
```

### Table-Driven Tests

✅ **GOOD:**
```go
func TestSubscription_CanAddDevice(t *testing.T) {
    tests := []struct {
        name            string
        sub             *domain.Subscription
        currentDevices  int32
        expectedAllowed bool
        expectedReason  string
    }{
        {
            name:            "No subscription",
            sub:             nil,
            currentDevices:  1,
            expectedAllowed: false,
            expectedReason:  "Subscription is not active",
        },
        {
            name: "Unlimited devices",
            sub: &domain.Subscription{
                Status: "active",
                Plan: domain.SubscriptionPlan{
                    Features: domain.Features{
                        LorawanCellularDevices: -1,
                    },
                },
            },
            currentDevices:  9999,
            expectedAllowed: true,
            expectedReason:  "Unlimited devices",
        },
        {
            name: "Below limit",
            sub: &domain.Subscription{
                Status: "active",
                Plan: domain.SubscriptionPlan{
                    Features: domain.Features{
                        LorawanCellularDevices: 5,
                    },
                },
            },
            currentDevices:  3,
            expectedAllowed: true,
            expectedReason:  "Devices left: 2",
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            allowed, reason := tt.sub.CanAddDevice(tt.currentDevices)
            assert.Equal(t, tt.expectedAllowed, allowed)
            assert.Equal(t, tt.expectedReason, reason)
        })
    }
}
```

### DTO / Domain / Entity / Events
- Domain models: no tags, no external deps (`app/internal/domain/...`).
- DTOs (delivery): `json`/`proto` tags only for transport.
- Entities (repository): `db`/ORM tags only for storage mapping.
- Events: `app/internal/messaging/.../created_v1.go` with `json` tags for publishing.
- Repositories hide infra models/tags, return domain types, and accept `ctx` with an existing transaction (never begin/commit/rollback).

### Context and timeouts
- Do not create `context.Background()` in handlers/usecases; use the incoming context.
- Deadlines/timeouts are set at boundaries (HTTP/gRPC servers, workers) and propagated downstream.
- Pass `ctx` to all I/O; do not swallow cancellation.

---

## 📦 Dependency Injection Pattern

Use manual DI in `app/internal/app` (composition root) to keep wiring explicit and testable.

### Main Application Assembly

✅ **GOOD:**
```go
// app/cmd/subscription/main.go
package main

import (
    "log"
    "github.com/yourapp/app/internal/app" // composition root
    "github.com/yourapp/app/internal/delivery/grpc"
    "github.com/yourapp/app/internal/repository/postgres"
    userrepo "github.com/yourapp/app/internal/repository/postgres/user"
    stripeclient "github.com/yourapp/app/internal/clients/stripe"
    "github.com/yourapp/app/internal/usecase/customer/get_subscription"
)

func main() {
    // Initialize configuration
    cfg, err := app.LoadConfig()
    if err != nil {
        log.Fatal(err)
    }
    
    // Initialize database
    db, err := postgres.NewDB(cfg.DatabaseURL)
    if err != nil {
        log.Fatal(err)
    }
    
    // Initialize adapters (Driven)
    userRepo := userrepo.NewUserRepository(db)          // implements usecase.UserRepository
    stripeRepo := stripeclient.NewCustomerRepository(cfg.StripeAPIKey, adapter)
    
    // Initialize usecases (Application layer)
    usecase := get_subscription.New(
        userRepo,
        stripeRepo,
        cfg.ContextReader,
    )
    
    // Initialize handlers (Delivery layer)
    customerHandler := grpc.NewCustomerServer(usecase)
    
    // Start server
    server := grpc.NewServer()
    pb.RegisterCustomerServiceServer(server, customerHandler)
    server.Serve(listener)
}
```

---

## ⚠️ Common Anti-Patterns to AVOID

### 1. God Object
❌ **NEVER create objects that do everything:**
```go
// ❌ BAD
type AppService struct {
    db          *gorm.DB
    cache       *redis.Client
    email       EmailClient
    stripe      StripeClient
    logger      Logger
    metrics     Metrics
    // ... 20 more dependencies
}
```

### 2. Anemic Domain Model
❌ **NEVER create domain models without behavior:**
```go
// ❌ BAD - Just a data container
type Subscription struct {
    ID     string
    Status string
}

// Business logic in service instead of domain
func (s *SubscriptionService) IsActive(sub Subscription) bool {
    return sub.Status == "active"
}
```

✅ **GOOD - Rich domain model:**
```go
// ✅ GOOD - Business logic in domain
type Subscription struct {
    ID     string
    Status string
}

func (s *Subscription) IsActive() bool {
    return s.Status == "active"
}
```

### 3. Circular Dependencies
❌ **NEVER create circular imports:**
```go
// ❌ service imports infrastructure
// ❌ infrastructure imports service
```

### 4. Leaky Abstractions
❌ **NEVER expose implementation details:**
```go
// ❌ BAD - Exposing GORM through interface
type UserRepository interface {
    GetDB() *gorm.DB // ❌ Leaking GORM
}
```

---

## 📋 Code Review Checklist

Before submitting code, verify:

- [ ] **Layering**: Is the layer separation correct? (Domain → Service → Infrastructure → Delivery)
- [ ] **SRP**: Does each struct/function have a single responsibility?
- [ ] **DIP**: Are dependencies injected through interfaces?
- [ ] **ISP**: Are interfaces small and focused?
- [ ] **Consumer-side Interfaces**: Are interfaces defined in the service layer (consumer), not infrastructure (provider)?
- [ ] **OCP**: Is the code extensible without modification?
- [ ] **No Business Logic**: in handlers or repositories
- [ ] **Domain Purity**: Domain layer has no external dependencies
- [ ] **Error Handling**: All errors are wrapped with context using `fmt.Errorf("context: %w", err)`
- [ ] **Logging**: Using `slog.InfoContext/ErrorContext` with context, not plain `log` or `slog.Info`
- [ ] **Context Propagation**: `context.Context` is first parameter and passed to all I/O operations
- [ ] **Testing**: Unit tests use mocks, not real infrastructure
- [ ] **Naming**: Clear, descriptive names following Go conventions
- [ ] **Run Tests**: Execute `make test` for the service after code changes
- [ ] **Run Linter**: Execute `make lint` for the service after code changes

---

## 🔌 Advanced Patterns

### Logging with Slog and Context

**CRITICAL**: Always use `log/slog` with context for structured logging. This enables distributed tracing and cross-service correlation.

✅ **GOOD:**
```go
import "log/slog"

func (s *SubscriptionEventService) HandleWebhook(
    ctx context.Context, 
    eventType stripe.EventType, 
    eventData any,
) error {
    // Use InfoContext, ErrorContext, WarnContext with structured fields
    slog.InfoContext(ctx, "Handling webhook event", 
        "event_type", eventType,
        "timestamp", time.Now())
    
    customerID, err := getCustomerID(eventData, eventType)
    if err != nil {
        slog.ErrorContext(ctx, "Failed to get customer ID",
            "event_type", eventType,
            "error", err,
            "stack_trace", fmt.Sprintf("%+v", err))
        return fmt.Errorf("failed to get customer ID: %w", err)
    }
    
    slog.InfoContext(ctx, "Processing subscription event",
        "customer_id", customerID,
        "event_type", eventType)
    
    // Context allows trace_id, request_id propagation
    return nil
}

// Usecase layer logging
func (u *Usecase) CreateCheckoutSession(
    ctx context.Context, 
    priceID string,
) (*domain.CheckoutSession, error) {
    slog.InfoContext(ctx, "Creating checkout session",
        "price_id", priceID)
    
    user, err := u.createOrGetUser(ctx, email)
    if err != nil {
        slog.ErrorContext(ctx, "Failed to create or get user",
            "price_id", priceID,
            "error", err)
        return nil, fmt.Errorf("failed to get or create customer: %w", err)
    }
    
    slog.InfoContext(ctx, "Checkout session created successfully",
        "price_id", priceID,
        "customer_id", user.StripeCustomerID)
    
    return session, nil
}
```

**Why Slog with Context?**
- **Structured logging** - easy to parse and search
- **Context propagation** - trace_id, request_id automatically included
- **Cross-service tracing** - enables distributed tracing (OpenTelemetry, Jaeger)
- **Performance** - Slog is optimized and efficient
- **Standard library** - no external dependencies

❌ **BAD:**
```go
import "log"

// ❌ Using old log package without context
func (s *Service) DoWork() error {
    log.Println("doing work") // ❌ No context, no structure
    
    err := s.repo.Save()
    if err != nil {
        log.Printf("error: %v", err) // ❌ No trace_id, no correlation
    }
}

// ❌ Using slog without context
func (s *Service) DoWork(ctx context.Context) error {
    slog.Info("doing work") // ❌ Missing InfoContext
    // Cannot correlate logs across services
}
```

---

### Interface Segregation - Go Idiomatic Way

**CRITICAL RULE**: Interfaces should be defined on the **consumer side** (where they are used), NOT on the provider side. This is idiomatic Go and follows ISP perfectly.

✅ **GOOD - Interfaces in Service Layer (Consumer):**
```go
// app/internal/usecase/customer/get_subscription/contract.go
package get_subscription

// Interface defined where it's USED (consumer side)
type UserRepository interface {
    GetUserByProfileID(ctx context.Context, profileId string) (*domain.User, error)
    CreateUser(ctx context.Context, user *domain.User) error
}

type StripeRepository interface {
    CreateCustomer(ctx context.Context, email string) (string, error)
    GetCustomerSubscription(ctx context.Context, customerID string) (*domain.Subscription, error)
}

// Usecase depends on small, focused interfaces
type Usecase struct {
    userRepo   UserRepository   // Consumer defines what it needs
    stripeRepo StripeRepository // Consumer defines what it needs
}

func New(
    userRepo UserRepository,
    stripeRepo StripeRepository,
) *Usecase {
    return &Usecase{
        userRepo:   userRepo,
        stripeRepo: stripeRepo,
    }
}
```

✅ **GOOD - Implementation in Infrastructure (Provider):**
```go
// app/internal/repository/postgres/user/repo.go
package userrepo

// Implementation does NOT define interface
// It just implements methods that the usecase needs
type UserRepository struct {
    db *pgx.Conn
}

func NewUserRepository(db *pgx.Conn) *UserRepository {
    return &UserRepository{db: db}
}

// Implements usecase.UserRepository interface implicitly
func (r *UserRepository) GetUserByProfileID(ctx context.Context, profileId string) (*domain.User, error) {
    // Implementation
}

func (r *UserRepository) CreateUser(ctx context.Context, user *domain.User) error {
    // Implementation
}

// Can have additional methods not in interface
func (r *UserRepository) GetUserByEmail(ctx context.Context, email string) (*domain.User, error) {
    // Extra method for other consumers
}
```

**Why Consumer-Side Interfaces?**
1. **ISP Compliance** - Each consumer defines only methods it needs
2. **No circular dependencies** - Infrastructure doesn't import service
3. **Easy testing** - Mock only what you use
4. **Flexibility** - Same implementation can satisfy multiple interfaces
5. **Go idiomatic** - "Accept interfaces, return structs"

**Example: Multiple Consumers, Different Interfaces**
```go
// app/internal/usecase/customer/get_subscription/contract.go
type UserReader interface {
    GetUserByProfileID(ctx context.Context, profileId string) (*domain.User, error)
}

type CustomerGetUsecase struct {
    users UserReader // Only needs reading
}

// app/internal/usecase/admin/user_update/contract.go
type UserWriter interface {
    CreateUser(ctx context.Context, user *domain.User) error
    UpdateUser(ctx context.Context, user *domain.User) error
    DeleteUser(ctx context.Context, id string) error
}

type AdminUserUsecase struct {
    users UserWriter // Only needs writing
}

// Same implementation satisfies both interfaces!
// app/internal/repository/postgres/user/repo.go
type UserRepository struct {
    db *pgx.Conn
}
// Implements all methods required by different usecases
```

❌ **BAD - Interface in Infrastructure (Provider):**
```go
// ❌ WRONG: Interface defined in infrastructure
// app/internal/repository/postgres/user/repo.go
package userrepo

// ❌ Provider defines interface - ANTI-PATTERN in Go
type UserRepository interface {
    GetUserByID(ctx context.Context, id string) (*domain.User, error)
    CreateUser(ctx context.Context, user *domain.User) error
    UpdateUser(ctx context.Context, user *domain.User) error
    DeleteUser(ctx context.Context, id string) error
    ListUsers(ctx context.Context) ([]domain.User, error)
    // ❌ Forces all consumers to depend on ALL methods
}

// Usecase forced to import infrastructure package
type CustomerUsecase struct {
    userRepo userrepo.UserRepository // ❌ Depends on infrastructure interface
}
```

**The Golden Rule:**
> "The consumer defines what it needs, the provider implements what it can."

---

### Context Management

Always pass and use `context.Context` for request-scoped values and cancellation.

✅ **GOOD:**
```go
// Extracting values from context through interface
type ContextReader interface {
    GetUserProfileID(ctx context.Context) (string, error)
}

type contextReader struct{}

func (r *contextReader) GetUserProfileID(ctx context.Context) (string, error) {
    profileID, ok := ctx.Value("user_profile_id").(string)
    if !ok {
        return "", fmt.Errorf("user profile ID not found in context")
    }
    return profileID, nil
}

// Usecase using context reader
func (u *Usecase) GetCustomerSubscription(ctx context.Context) (*domain.Subscription, error) {
    profileID, err := u.ctxReader.GetUserProfileID(ctx)
    if err != nil {
        return nil, fmt.Errorf("failed to get user profile ID: %w", err)
    }
    
    // Pass context to all downstream calls
    user, err := u.userRepo.GetUserByProfileID(ctx, profileID)
    if err != nil {
        return nil, fmt.Errorf("failed to get user: %w", err)
    }
    
    return subscription, nil
}
```

**Context Best Practices:**
- Always first parameter in functions
- Pass to all I/O operations (DB, HTTP, gRPC)
- Use for cancellation and timeouts
- Store request-scoped values (user ID, trace ID)

❌ **BAD:**
```go
// ❌ Not passing context
func (s *Service) DoWork() error {
    s.repo.GetData() // ❌ Missing context
}

// ❌ Creating context inside function
func (s *Service) DoWork() error {
    ctx := context.Background() // ❌ Should be passed from caller
    s.repo.GetData(ctx)
}
```

---

### Interceptors / Middleware Pattern

Use interceptors for cross-cutting concerns (auth, logging, feature flags).

✅ **GOOD:**
```go
// app/internal/delivery/grpc/interceptors.go
package grpc

import (
    "context"
    "google.golang.org/grpc"
    "github.com/yourapp/app/internal/feature"
)

// Unary interceptor for feature flags
func NewUnaryInterceptor(client feature.FliptClient) grpc.UnaryServerInterceptor {
    return func(
        ctx context.Context, 
        req any, 
        info *grpc.UnaryServerInfo, 
        handler grpc.UnaryHandler,
    ) (any, error) {
        // Add feature flag provider to context
        provider := feature.FliptProvider{Client: client}
        enhancedCtx := feature.WithProvider(ctx, provider)
        
        // Call actual handler with enhanced context
        return handler(enhancedCtx, req)
    }
}

// Stream interceptor
func NewStreamInterceptor(client feature.FliptClient) grpc.StreamServerInterceptor {
    return func(
        srv any, 
        ss grpc.ServerStream, 
        info *grpc.StreamServerInfo, 
        handler grpc.StreamHandler,
    ) error {
        provider := feature.FliptProvider{Client: client}
        enhancedCtx := feature.WithProvider(ss.Context(), provider)
        
        wrappedStream := &wrappedServerStream{
            ServerStream: ss,
            ctx:          enhancedCtx,
        }
        
        return handler(srv, wrappedStream)
    }
}

type wrappedServerStream struct {
    grpc.ServerStream
    ctx context.Context
}

func (w *wrappedServerStream) Context() context.Context {
    return w.ctx
}
```

**Chain multiple interceptors:**
```go
// cmd/app/main.go
grpcServer := grpcserver.NewServer(
    grpcserver.ChainUnaryInterceptor(
        grpc.NewUnaryInterceptor(fliptClient),    // Feature flags
        jwtAuth.UnaryInterceptor(),                // Authentication
        logging.UnaryInterceptor(),                 // Logging
    ),
)
```

---

### Error Handling Best Practices

Always wrap errors with context and handle them properly at each layer.

**Mandatory shared error library (Go services):**
- Use `github.com/chirpwireless/go-kit/errs` as the structured domain error type.
- For gRPC boundaries, use `github.com/chirpwireless/go-kit/errs/grpc`:
  - `errsgrpc.ToStatus(err)` when returning gRPC errors from servers.
  - `errsgrpc.FromStatus(err)` when consuming gRPC errors in clients.
- If a user-facing message is needed, set `errs.E.WithHumanDesc(...)` and surface it at the transport layer (HTTP or gRPC).
- Do not introduce custom gRPC error mappers or localized-message wrappers when `go-kit/errs` can be used.

✅ **GOOD:**
```go
// Usecase layer - add context to errors
func (u *Usecase) CreateCheckoutSession(
    ctx context.Context, 
    priceID string,
) (*domain.CheckoutSession, error) {
    user, err := u.createOrGetUser(ctx, email)
    if err != nil {
        // Wrap error with context about what failed
        return nil, fmt.Errorf("failed to get or create customer: %w", err)
    }
    
    existingSubscription, err := u.stripeRepo.GetCustomerSubscription(ctx, user.StripeCustomerID)
    if err != nil {
        return nil, fmt.Errorf("failed to check existing subscription: %w", err)
    }
    
    // Validate business rules
    if existingSubscription != nil && existingSubscription.IsActive() {
        return nil, fmt.Errorf("user already has an active subscription: %s", 
            existingSubscription.StripeSubscriptionID)
    }
    
    session, err := u.stripeRepo.CreateCheckoutSession(ctx, params)
    if err != nil {
        return nil, fmt.Errorf("failed to create checkout session: %w", err)
    }
    
    return session, nil
}

// Infrastructure layer - wrap external errors
func (r *CustomerRepository) CreateCustomer(ctx context.Context, email string) (string, error) {
    params := &stripe.CustomerParams{
        Email: stripe.String(email),
    }
    
    customer, err := r.client.CreateCustomer(ctx, params)
    if err != nil {
        // Wrap external API error
        return "", fmt.Errorf("failed to create customer: %w", err)
    }
    
    return customer.ID, nil
}
```

**Error wrapping rules:**
1. Use `fmt.Errorf("context: %w", err)` to wrap errors
2. Add meaningful context at each layer
3. Don't swallow errors
4. Return domain errors when appropriate
5. Use `errors.Is()` and `errors.As()` for error checking

**Error context rules (mandatory):**
1. Do not replace errors with a generic message in usecase/repo layers
2. Each wrap must describe the action and target; mention the dependency only when it adds clarity (e.g., RPC/SQL/service)
3. Generic `internal server error` is only produced at transport/handler layer
4. Preserve domain errors; use `errors.Is/As` instead of string checks
5. Do not return raw errors or `err.Error()` in client responses; map to safe messages
6. Handlers must log every error response with context

❌ **BAD:**
```go
// ❌ Swallowing errors
func (s *Service) DoWork() error {
    err := s.repo.Save()
    if err != nil {
        log.Println(err) // ❌ Logged but not returned
        return nil
    }
}

// ❌ Not wrapping errors
func (s *Service) DoWork() error {
    err := s.repo.Save()
    if err != nil {
        return err // ❌ No context added
    }
}

// ❌ Creating new error instead of wrapping
func (s *Service) DoWork() error {
    err := s.repo.Save()
    if err != nil {
        return fmt.Errorf("failed to save") // ❌ Lost original error
    }
}
```

---

### Repository Interface Testability

Always define repository methods to return domain errors for easier testing.

✅ **GOOD:**
```go
// Repository returns domain error
func (r *UserRepository) GetUserByOrganizationID(
    ctx context.Context, 
    organizationID string,
) (domain.User, error) {
    var user User
    err := r.db.QueryRow(ctx, `select ... from users where organization_id=$1`, organizationID).Scan(&user...)
    if err != nil {
        if errors.Is(err, pgx.ErrNoRows) {
            // Return domain error, not driver error
            return domain.User{}, fmt.Errorf("no user with organization_id=%q: %w", organizationID, domain.ErrNotFound)
        }
        return domain.User{}, fmt.Errorf("getting user by organization_id: %w", err)
    }
    return *toDomainUser(&user), nil
}

// Usecase can check for domain errors
func (u *Usecase) GetUser(ctx context.Context, orgID string) (*domain.User, error) {
    user, err := u.userRepo.GetUserByOrganizationID(ctx, orgID)
    if err != nil {
        if errors.Is(err, domain.ErrNotFound) {
            // Handle not found specifically
            return nil, fmt.Errorf("user not found")
        }
        return nil, err
    }
    return &user, nil
}
```

---

## 🎓 Summary

**Remember:**
1. **Domain** = Business rules and entities (pure Go)
2. **Service** = Use cases and orchestration (depends on interfaces)
3. **Infrastructure** = Implementation details (DB, APIs, external services)
4. **Delivery** = API handlers (thin transformation layer)

**Dependencies flow:**
```
Delivery → Service → Domain ← Infrastructure
```

**Key Patterns:**
- **Consumer-side interfaces** - Define interfaces where they are used (Go idiomatic)
- **Slog with Context** - Always use `slog.InfoContext`, `slog.ErrorContext` for distributed tracing
- **Context propagation** - Pass `context.Context` everywhere for cancellation and tracing
- **Interceptors** - For cross-cutting concerns (auth, logging, feature flags)
- **Error wrapping** - With context at every layer using `fmt.Errorf("context: %w", err)`
- **Dependency Injection** - Through constructor with interfaces

**Always ask yourself:**
- "Does this violate SOLID?"
- "Can I test this without a real database?"
- "Is this the right layer for this code?"
- "Would changing the database break my domain logic?" (Should be NO)
- "Am I wrapping errors with meaningful context?"
- "Is this dependency injected through an interface?"
- "Is the interface defined on the consumer side?" (Should be YES)
- "Am I using `slog.InfoContext/ErrorContext` with context?" (Should be YES)

Follow these principles rigorously and your code will be **maintainable**, **testable**, and **scalable**.
