# Flyway — Quick Guide

## What is Flyway?

Flyway is a tool that manages your database automatically.
Instead of running SQL manually in MySQL Workbench every time,
Flyway runs your SQL files automatically when the Spring Boot app starts.

---

## The problem it solves

Without Flyway:
```
You add a column manually in MySQL Workbench on your laptop
→ Works on your laptop ✅
→ Server does not have it → app crashes ❌
→ Teammate does not have it → app crashes ❌
```

With Flyway:
```
You add a new SQL file to the project
→ Everyone who starts the app gets the change automatically if they are using a local database ✅
→ Server gets it automatically on deploy ✅
```

---

## How it works — 3 simple steps

**Step 1 — You write SQL files with version numbers**

```
src/main/resources/db/migration/
  V1__create_users_table.sql
  V2__create_user_devices_table.sql
  V3__create_refresh_tokens_table.sql
  V4__create_user_preferences_table.sql
  V5__create_user_sessions_table.sql
  V6__create_password_reset_tokens_table.sql
```

**Step 2 — Spring Boot app starts**

Flyway wakes up automatically and checks your database:

```
"Has V1 been run?" → No → runs it → users table created
"Has V2 been run?" → No → runs it → user_devices table created
"Has V3 been run?" → No → runs it → refresh_tokens table created
... and so on until all files are run
```

**Step 3 — Next time app starts**

```
"Has V1 been run?" → Yes → skip
"Has V2 been run?" → Yes → skip
... all skipped, app starts in seconds
```

---

## Version numbers = run order, not table version

```
V1 = first thing to run  → create users
V2 = second thing to run → create user_devices
V3 = third thing to run  → create refresh_tokens
```

The number tells Flyway what order to run the files.
It is not the version of the table.

Order matters because of foreign keys:
```
user_devices has → FOREIGN KEY (user_id) REFERENCES users(id)

So users must be created before user_devices.
V1 creates users, V2 creates user_devices → works ✅
```

---

## Adding a change later

Next month you need to add `phone_number` to users:

```
DO NOT touch V1__create_users_table.sql  ← Flyway never runs a file twice
```

Instead create a new file:

```
V7__add_phone_number_to_users.sql

Content:
ALTER TABLE users ADD COLUMN phone_number VARCHAR(20);
```

Everyone who starts the app gets this change automatically.

---

## What Flyway creates in your database

Flyway creates one extra table called `flyway_schema_history`
to track which files have already been run:

| version | description | installed_on | success |
|---------|-------------|--------------|---------|
| 1 | create users table | 2026-05-17 09:00 | true |
| 2 | create user devices table | 2026-05-17 09:00 | true |
| 3 | create refresh tokens table | 2026-05-17 09:00 | true |

You never touch this table — Flyway manages it automatically.

------------------------------

## Setup in Spring Boot

**pom.xml — add this dependency:**

```xml
<dependency>
    <groupId>org.flywaydb</groupId>
    <artifactId>flyway-mysql</artifactId>
</dependency>
```

**application.yml — add these lines:**

```yaml
spring:
  datasource:
    url: jdbc:mysql://localhost:3306/citypulse_users
    username: root
    password: your_password
  flyway:
    enabled: true
    locations: classpath:db/migration
```

That is all. Flyway runs automatically every time the app starts.

---

## Summary

| Without Flyway | With Flyway |
|---|---|
| Run SQL manually each time | SQL runs automatically on app start |
| Easy to forget a change | Every change is in a file in Git |
| Team gets out of sync | Everyone always has the same tables |
| No history of changes | Full history — one file per change |
| Hard to recreate from scratch | Any machine recreates perfectly |
