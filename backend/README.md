<div align="center">

<img src="logo.webp" alt="VIVRE" width="160" />

### Personal Operating System — Backend

**A unified API for work, life, health, and reflection.**

[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?style=flat-square&logo=python&logoColor=white)](https://www.python.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115-009688?style=flat-square&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15+-4169E1?style=flat-square&logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Redis](https://img.shields.io/badge/Redis-7+-DC382D?style=flat-square&logo=redis&logoColor=white)](https://redis.io/)
[![Celery](https://img.shields.io/badge/Celery-5.4-37814A?style=flat-square&logo=celery&logoColor=white)](https://docs.celeryq.dev/)
[![License](https://img.shields.io/badge/License-Proprietary-111827?style=flat-square)](#license)

[Overview](#overview) · [Architecture](#architecture) · [Quick Start](#quick-start) · [API](#api-surface) · [Deployment](#deployment) · [Contributing](#contributing)

</div>

---

## Overview

VIVRE is a **personal operating system** — a single backend that unifies the tools people normally juggle across six different apps: notes, project management, habit tracking, health metrics, journaling, and AI-assisted reflection.

It is built as an **async-first, event-driven API** designed for tens of thousands of daily active users on modest infrastructure.

> **Design principles**
> - **One identity, many surfaces.** Every resource belongs to a `user_id` — scoped, compartmentalized, and permission-checked at the service layer.
> - **Async everywhere.** Non-blocking I/O on the request path; blocking SDK calls are offloaded to worker threads.
> - **Events over direct coupling.** Services publish domain events; background Celery workers deliver notifications.
> - **Database-enforced invariants.** Unique constraints, check constraints, and correct cascades — not just application-level guards.

---

## Feature highlights

<table>
<tr>
<td width="50%" valign="top">

### 🔐 Identity
- Email + password (bcrypt)
- Google OAuth sign-in
- OTP email verification
- OTP password reset
- Rotating refresh tokens with per-session revocation
- Login-failure throttling

### 📝 Notes
- Folders (hierarchical)
- Notes with version history
- Note-to-note links
- Quick captures inbox
- Recent & pinned views

### 💼 Work
- Clients
- Projects, milestones, tasks
- Subtasks & dependencies (cycle-safe)
- Project templates
- Focus sessions & activity log
- Project cover images

</td>
<td width="50%" valign="top">

### 🌱 Personal
- Goals & key results
- Habits with streaks
- Journal entries
- Calendar events
- Time blocks
- Daily activities

### 💚 Health
- Daily metrics (steps, calories, distance)
- Sleep records
- Workouts
- Device connections

### 🧠 Reflection
- Daily & weekly reviews
- Free-form reflections
- AI plan-from-objective

### 🔔 Notifications
- In-app, push (FCM), email (Brevo)
- Real-time SSE stream
- Per-category preferences
- Digest scheduling

</td>
</tr>
</table>

---

## Architecture

```
                          ┌────────────────────────────────┐
                          │            Clients             │
                          │    Web  ·  Mobile  ·  CLI      │
                          └─────────────┬──────────────────┘
                                        │  HTTPS  ·  Server-Sent Events
                                        ▼
              ┌───────────────────────────────────────────────────────┐
              │                 FastAPI application                   │
              │  ─ routers   ─ middleware   ─ schemas   ─ services    │
              └───┬───────────────┬──────────────────┬────────────────┘
                  │               │                  │
                  ▼               ▼                  ▼
        ┌─────────────────┐ ┌─────────────┐ ┌─────────────────────┐
        │   PostgreSQL    │ │    Redis    │ │  Celery  (workers)  │
        │      Neon       │ │ cache·queue │ │  Celery  (beat)     │
        │  asyncpg pool   │ │  pub/sub    │ │  scheduled jobs     │
        └─────────────────┘ └──────┬──────┘ └──────────┬──────────┘
                                    │                    │
                                    └────────┬───────────┘
                                             ▼
                             ┌───────────────────────────────┐
                             │        Integrations           │
                             │  Cloudinary  ·  Firebase FCM  │
                             │  Brevo       ·  OpenAI /      │
                             │                  Anthropic    │
                             └───────────────────────────────┘
```

### Request flow

```
Request ─▶ Proxy middleware ─▶ CORS ─▶ Correlation ID ─▶ Guard ─▶ Rate Limit
                                                                      │
                                                                      ▼
                                                Router ─▶ Service ─▶ Postgres / Redis
                                                              │
                                                              └─▶ Event Bus ─▶ Celery
```

### Event-driven notifications

```
Task completed  ─▶  event_bus.publish(TASK_COMPLETED)  ─▶  Celery fan-out
                                                                │
                                                             process event
                                                                │
                                       preference check ────────┴───────▶ INSERT notification
                                                                                │
                                                                                ▼
                                                              SSE stream  ──▶ client
```

---

## Tech stack

| Layer | Technology | Notes |
|---|---|---|
| Language | **Python 3.11+** | `asyncio`, `zoneinfo` |
| Web framework | **FastAPI** | Routers, dependency injection, Pydantic v2 |
| ASGI server | **Uvicorn** behind **Gunicorn** | `UvicornWorker`, one worker per CPU × 2 + 1 |
| ORM | **SQLAlchemy 2.0** (async) | `asyncpg` driver |
| Migrations | **Alembic** | Advisory-locked, runs at startup |
| Primary DB | **PostgreSQL** (Neon) | Pooler aware, statement timeouts enforced |
| Cache & queue | **Redis** | Rate limiting, OTP, sessions, SSE pub/sub, Celery broker |
| Background jobs | **Celery + Beat** | Digests, notification delivery, event fan-out |
| Auth | **JWT** (PyJWT) | Access 15 min · refresh 30 days, rotating |
| Hashing | **bcrypt** | SHA-256 pre-hash + bcrypt cost 12 |
| Media | **Cloudinary** | Avatars, project covers |
| Email | **Brevo** | Transactional templates |
| Push | **Firebase Cloud Messaging** | Token lifecycle managed in Redis |
| AI | **OpenAI** / **Anthropic** | Chat, capture, plan |
| Logging | **structlog** | JSON, request-scoped context, sensitive-key redaction |

---

## Quick start

### 1. Prerequisites

| Requirement | Version |
|---|---|
| Python | 3.11 or newer |
| PostgreSQL | 15 or newer (or a Neon connection string) |
| Redis | 7 or newer |
| A container runtime *(optional)* | Docker 24+ |

### 2. Clone & install

```bash
git clone git@github.com:your-org/vivre.git
cd vivre
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
```

### 3. Configure

```bash
cp .env.example .env
# fill in: DATABASE_URL, REDIS_URL, JWT_SECRET_KEY, TOKEN_ENCRYPTION_KEY,
#          CLOUDINARY_*, BREVO_*, GOOGLE_*, AI_*, CORS_ORIGINS
```

Generate the two required secrets:

```bash
python -c "import secrets; print(secrets.token_urlsafe(48))"
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

### 4. Run

```bash
# API
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Celery worker        (separate terminal)
celery -A app.workers.celery_app.celery_app worker -l info

# Celery beat          (separate terminal)
celery -A app.workers.celery_app.celery_app beat -l info
```

Migrations run **automatically at application startup** behind a Postgres advisory lock, so it is safe to run multiple replicas concurrently.

Interactive docs are available at **`http://localhost:8000/docs`** in non-production environments.

---

## Environment variables

| Group | Variables | Required |
|---|---|---|
| **Runtime** | `ENVIRONMENT`, `LOG_LEVEL` | ✅ |
| **Database** | `DATABASE_URL`, `DATABASE_POOL_SIZE`, `DATABASE_MAX_OVERFLOW`, `DATABASE_POOL_RECYCLE_SECONDS`, `DATABASE_POOL_TIMEOUT_SECONDS`, `DATABASE_STATEMENT_TIMEOUT_SECONDS`, `DATABASE_CONNECT_TIMEOUT_SECONDS`, `MIGRATIONS_CONNECT_TIMEOUT_SECONDS` | ✅ `DATABASE_URL` |
| **Redis** | `REDIS_URL` | ✅ |
| **Security** | `JWT_SECRET_KEY`, `TOKEN_ENCRYPTION_KEY`, `TRUST_PROXY_HEADERS` | ✅ first two |
| **Cloudinary** | `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET` | ✅ |
| **Firebase** | `FIREBASE_SERVICE_ACCOUNT_JSON` | ✅ for push |
| **Brevo** | `BREVO_API_KEY`, `BREVO_FROM_EMAIL`, `BREVO_FROM_NAME` | ✅ |
| **Google** | `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REDIRECT_URI` | ✅ for OAuth |
| **AI** | `AI_PROVIDER`, `AI_PROVIDER_API_KEY`, `AI_MODEL_NAME` | ✅ |
| **CORS** | `CORS_ORIGINS` | ✅ explicit allow-list in production |

> The application **refuses to start** in production unless `CORS_ORIGINS` is a non-wildcard list, `JWT_SECRET_KEY` is ≥ 32 characters, and `TOKEN_ENCRYPTION_KEY` is present whenever Google is enabled.

---

## Project structure

```
app/
├── main.py                 FastAPI app, lifespan, exception handlers
├── events.py               In-process domain event bus
│
├── api/                    HTTP layer — routers only
│   ├── deps.py             Shared FastAPI dependencies
│   ├── auth.py             /auth
│   ├── users.py            /users
│   ├── notes.py            /notes
│   ├── work.py             /work
│   ├── personal.py         /personal
│   ├── health.py           /health-metrics
│   ├── reviews.py          /reviews
│   ├── ai.py               /ai
│   ├── notifications.py    /notifications
│   └── shared.py           /, /health, /health/ready, /timeline, /search
│
├── services/               Business logic — one module per domain
├── schemas/                Pydantic request & response models
├── models/                 SQLAlchemy ORM models
├── integrations/           Third-party SDK adapters
├── workers/                Celery app & tasks
│
├── core/                   Config, logging, security, middleware, exceptions
└── db/                     Session, Redis, migrations, pool helpers
```

---

## API surface

Every endpoint is **JWT-authenticated** unless flagged otherwise. All list endpoints are paginated (`limit`, `offset`).

### Identity — `/auth`

| Method | Path | Description |
|---|---|---|
| `POST` | `/auth/signup` | Create an account |
| `POST` | `/auth/login` | Email + password |
| `POST` | `/auth/google` | Google ID-token sign-in |
| `POST` | `/auth/refresh` | Rotate refresh token |
| `POST` | `/auth/logout` | Revoke refresh session |
| `POST` | `/auth/email/verify/request` | Send verification OTP |
| `POST` | `/auth/email/verify` | Confirm verification OTP |
| `POST` | `/auth/password/forgot` | Request password reset OTP |
| `POST` | `/auth/password/reset` | Confirm password reset |

### Profile — `/users`

| Method | Path | Description |
|---|---|---|
| `GET`, `PATCH` | `/users/me` | Read / update profile |
| `POST`, `DELETE` | `/users/me/avatar` | Upload / remove avatar |
| `GET` | `/users/me/google/authorize-url` | Begin Google connection |
| `GET` | `/users/me/google` | Connection status |
| `GET` | `/users/me/google/callback` | OAuth callback |
| `DELETE` | `/users/me/google` | Disconnect Google |

### Notes — `/notes`

| Method | Path | Description |
|---|---|---|
| `POST`, `GET` | `/notes/folders` | Create / list folders |
| `PATCH`, `DELETE` | `/notes/folders/{id}` | Update / delete folder |
| `POST`, `GET` | `/notes` | Create / list notes |
| `GET` | `/notes/recent` | Recently accessed |
| `GET`, `PATCH`, `DELETE` | `/notes/{id}` | Note detail, update, delete |
| `POST` | `/notes/{id}/links` | Link two notes |
| `DELETE` | `/notes/links/{id}` | Remove link |
| `POST`, `GET` | `/notes/quick-captures` | Create / list captures |
| `POST` | `/notes/quick-captures/{id}/process` | Mark processed |

### Work — `/work`

| Method | Path | Description |
|---|---|---|
| `POST`, `GET` | `/work/clients` | Clients |
| `POST`, `GET` | `/work/templates` | Project templates |
| `POST` | `/work/templates/instantiate` | Instantiate a template |
| `POST`, `GET` | `/work/projects` | Projects |
| `GET`, `PATCH`, `DELETE` | `/work/projects/{id}` | Project detail / update / delete |
| `POST`, `DELETE` | `/work/projects/{id}/cover` | Cover image |
| `POST` | `/work/projects/{id}/milestones` | Create milestone |
| `GET` | `/work/projects/{id}/activity` | Project audit log |
| `POST`, `GET` | `/work/tasks` | Tasks |
| `GET`, `PATCH`, `DELETE` | `/work/tasks/{id}` | Detail / update / delete |
| `PATCH` | `/work/tasks/{id}/parent` | Re-parent (cycle-safe) |
| `POST` | `/work/tasks/{id}/dependencies` | Add dependency |
| `POST` | `/work/focus-sessions` | Start focus session |
| `POST` | `/work/focus-sessions/{id}/stop` | Stop focus session |

### Personal — `/personal`

Goals · Key results · Habits (with `/streak` and `/logs`) · Journal · Events · Time blocks · Daily activities.

### Health — `/health-metrics`

Daily metrics · Sleep · Workouts · Device connections.

### Reviews — `/reviews`

Daily reviews (+ `/{date}/context`) · Weekly reviews · Reflections.

### AI — `/ai`

| Method | Path | Description |
|---|---|---|
| `POST` | `/ai/chat` | Contextual chat |
| `POST` | `/ai/capture` | Classify free text → note / task / habit / journal |
| `POST` | `/ai/plan` | Break an objective into steps |

### Notifications — `/notifications`

| Method | Path | Description |
|---|---|---|
| `GET` | `/notifications` | Paginated list |
| `GET` | `/notifications/stream` | **Server-Sent Events** real-time feed |
| `PATCH` | `/notifications/{id}/read` | Mark one read |
| `POST` | `/notifications/read-all` | Mark all read |
| `GET`, `PATCH` | `/notifications/preferences` | Notification preferences |
| `POST`, `DELETE` | `/notifications/device-tokens` | Register / unregister push token |

### Shared

| Method | Path | Description |
|---|---|---|
| `GET` | `/` | Service banner |
| `GET` | `/health` | Liveness |
| `GET` | `/health/ready` | DB + Redis readiness |
| `GET` | `/timeline?date=YYYY-MM-DD` | Unified day timeline |
| `GET` | `/search?q=…` | Cross-domain search |

---

## Background jobs

| Job | Schedule | Purpose |
|---|---|---|
| `deliver_pending_notifications_task` | every 60 s | Flush email / push / in-app queue |
| `dispatch_daily_review_prompts_task` | hourly | Fan out review prompts to users in the matching local hour |
| `dispatch_weekly_digest_emails_task` | hourly | Fan out weekly digests to users in the matching local weekday/hour |
| `process_*_event_task` | on event | Deliver task / habit / goal / milestone notifications |

All tasks are **idempotent** — daily and weekly digests use Redis `SET NX` guards so running a schedule twice in the same window produces no duplicates.

---

## Deployment

### Container layout

Run three processes against the same image, differing only by start command:

| Process | Command | Replicas |
|---|---|---|
| API | `gunicorn app.main:app -k uvicorn.workers.UvicornWorker -w 4 -b 0.0.0.0:8000` | ≥ 2 |
| Worker | `celery -A app.workers.celery_app.celery_app worker -l info -Q vivre` | ≥ 2 |
| Beat | `celery -A app.workers.celery_app.celery_app beat -l info` | **exactly 1** |

### Production checklist

- [ ] `ENVIRONMENT=production`
- [ ] `JWT_SECRET_KEY` ≥ 32 cryptographically random characters
- [ ] `TOKEN_ENCRYPTION_KEY` generated and backed up (rotating it invalidates stored Google tokens)
- [ ] `DATABASE_URL` uses `sslmode=require` and points at the Neon pooler endpoint
- [ ] `REDIS_URL` uses `rediss://` with auth
- [ ] `CORS_ORIGINS` is an explicit allow-list — **no `*`**
- [ ] `TRUST_PROXY_HEADERS=true` **only** behind a trusted proxy (load balancer or ingress)
- [ ] At least one Celery worker is running — otherwise notifications pile up
- [ ] Exactly one Celery beat is running
- [ ] `.env` is injected via your secret manager, **never baked into the image**

### Health probes

| Probe | Path | Expectation |
|---|---|---|
| Liveness | `GET /health` | `200` |
| Readiness | `GET /health/ready` | `200` with `{"status": "ok", "database": true, "redis": true}` |

A `503`-style response on readiness means the orchestrator should stop sending traffic — the API will still return `200` but with `"status": "degraded"` so you can distinguish transient dependency loss from a broken pod.

---

## Security

- **Password hashing** uses SHA-256 pre-hash + bcrypt cost 12, with a constant-time dummy hash for non-existent accounts to eliminate account-enumeration timing leaks.
- **Access tokens** live 15 minutes; **refresh tokens** rotate on every use and can be revoked per-session.
- **Login throttling** counts failures per email in Redis and rejects beyond a threshold within a sliding window.
- **Sensitive log fields** (`password`, `token`, `authorization`, `api_key`, `client_secret`, …) are automatically redacted before they reach the log sink.
- **Upload guards** enforce a content-type allow-list and a body-size cap enforced **at the ASGI layer**, before FastAPI parses the request.
- **SQL injection** is impossible through the ORM — every query is parameterized.
- **Search inputs** have SQL `LIKE` wildcards escaped before reaching the database.

---

## Operational notes

- **Migrations** run in the API's startup lifespan, guarded by a Postgres advisory lock — safe for rolling deploys. For zero-downtime at very large scale, promote them to a dedicated pre-deploy job.
- **Connection pooling** uses LIFO with `pool_pre_ping`, sized explicitly — tune `DATABASE_POOL_SIZE` and `DATABASE_MAX_OVERFLOW` together to match your Postgres plan.
- **Hot list endpoints** benefit from composite indexes; run `EXPLAIN ANALYZE` against your slowest query before adjusting pool sizes.
- **Cross-domain search** is currently a `LIKE` scan across eight tables — add `pg_trgm` GIN indexes when search latency becomes visible.

---

## Contributing

1. Branch from `main`: `git checkout -b feat/your-feature`
2. Follow the code style — every source file starts with a single `# app/path/to/file.py` header comment; no other comments.
3. Run a full local linter + test pass before opening a PR.
4. Keep commits small and scoped; descriptive PR titles (`feat(notes): add bulk folder move`).
5. Every new endpoint must be authenticated by default and scoped to `current_user.id` in the service layer.

---

## License

Proprietary. © VIVRE — all rights reserved.

---

<div align="center">

<img src="logo.webp" alt="VIVRE" width="80" />

**Built for people who refuse to live in six different apps.**

</div>