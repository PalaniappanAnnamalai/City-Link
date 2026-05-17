
## `users`

### What does it store?

One row per registered person. Name, email, hashed password, role, and which
NZ city they want to see on their dashboard.

### Real example

Imagine three people sign up for CityPulse:

| id | name | email | password | role | city | enabled |
|----|------|-------|----------|------|------|---------|
| 1 | Raj Kumar | raj@gmail.com | $2a$10$abc... | USER | Auckland | true |
| 2 | Sarah Chen | sarah@gmail.com | $2a$10$xyz... | USER | Wellington | true |
| 3 | Admin User | admin@citypulse.nz | $2a$10$def... | ADMIN | Auckland | true |

The `password` column never stores the actual password — only a BCrypt hash.
Even if someone hacks the database they cannot recover the original passwords.

The `enabled` column is how an admin blocks a user without deleting them. If
Raj's account is flagged as suspicious, set `enabled = false`. His data stays
safe, he just cannot log in.

### Create table SQL
```sql
CREATE TABLE IF NOT EXISTS users (
    id              BIGINT AUTO_INCREMENT   PRIMARY KEY,
    name            VARCHAR(100)            NOT NULL,
    email           VARCHAR(150)            NOT NULL UNIQUE,
    password        VARCHAR(255)            NOT NULL,
    role            ENUM('USER','ADMIN')    NOT NULL DEFAULT 'USER',
    city            VARCHAR(50)                      DEFAULT 'Auckland',
    enabled         BOOLEAN                 NOT NULL DEFAULT TRUE,
    created_at      DATETIME                NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME                NOT NULL DEFAULT CURRENT_TIMESTAMP
                                                     ON UPDATE CURRENT_TIMESTAMP
);
```

### each column

| Column | Why |
|--------|-----|
| `id` | Unique number for each user. Used internally to link tables together |
| `name` | Shown on the dashboard — "Good morning, Raj" |
| `email` | Used to log in. `UNIQUE` means two people cannot register with the same email |
| `password` | BCrypt hash — always 60 characters. `VARCHAR(255)` gives room if the hashing method ever changes |
| `role` | `USER` can use the app. `ADMIN` can manage users and see system stats |
| `city` | Which NZ city to load on the dashboard. Defaults to Auckland if not set |
| `enabled` | Quick on/off switch. Better than deleting — history is preserved |
| `created_at` | When they registered. Set automatically, never changed manually |
| `updated_at` | When their profile was last changed. Updated automatically on every save |

---

## `user_devices`

### What does it store?

One row per device a user has logged in from. If Raj logs in on his Android
phone, his wife's iPhone, and his laptop browser, that is 3 rows in this
table, all pointing to Raj's user id.

### Why do we need a separate table for this?

Because a user is a person, but a device is hardware. They are two different
things.

The `users` table knows **who** Raj is.
The `user_devices` table knows **what devices** Raj is using.

Without this table you cannot:

- Send a push notification to his phone (you need the FCM token stored here)
- Show him "these are your active devices" in settings
- Let him log out one device without logging out all devices
- Keep Android logged in for 90 days but browser for only 7 days

### Real example

Raj logs into CityPulse on three devices:

| id | user_id | device_name         | os_type | fcm_token  | is_active |
|----|---------|-------------        |---------|----------- |-----------|
| 1  | 1       | Raj's Samsung S24   | ANDROID | fcm_abc... | true |
| 2  | 1       | Raj's MacBook       | WEB     | null       | true |
| 3  | 1       | Wife's iPhone 15    | IOS     | fcm_xyz... | true |

Notice:
- ANDROID and IOS rows have an `fcm_token` -  Firebase uses this address to
  deliver push notifications to that exact device
- The WEB row has `fcm_token = null` - browsers don't use Firebase, they
  get real-time alerts via WebSocket instead
- All three rows have `user_id = 1` -  they all belong to Raj



### Create table SQL
```sql
CREATE TABLE IF NOT EXISTS user_devices (
    id                  BIGINT AUTO_INCREMENT       PRIMARY KEY,
    user_id             BIGINT                      NOT NULL,
    device_fingerprint  VARCHAR(255)                NOT NULL UNIQUE,
    device_name         VARCHAR(150),
    device_model        VARCHAR(100),
    os_type             ENUM('ANDROID','IOS','WEB') NOT NULL,
    os_version          VARCHAR(50),
    app_version         VARCHAR(20),
    fcm_token           VARCHAR(512),
    is_active           BOOLEAN                     NOT NULL DEFAULT TRUE,
    registered_at       DATETIME                    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen_at        DATETIME                    NOT NULL DEFAULT CURRENT_TIMESTAMP
                                                             ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```
### Why each column exists

| Column | Why |
|--------|-----|
| `user_id` | Links this device to a person in the `users` table |
| `device_fingerprint` | Unique ID the Android/iOS app generates on first install. Prevents the same phone registering twice |
| `device_name` | Human readable - "Raj's Samsung S24". Shown in the active devices screen |
| `device_model` | Raw hardware model e.g. "SM-S928B". Useful when debugging crashes on specific phones |
| `os_type` | ANDROID / IOS / WEB. Spring uses this to give mobile a 90-day token and web a 7-day token |
| `os_version` | e.g. "Android 14". Helps you decide when to drop support for old OS versions |
| `app_version` | e.g. "1.0.3". Updated on every API call. Used to force-upgrade outdated app versions |
| `fcm_token` | Firebase push address. Null for web browsers use WebSocket instead |
| `is_active` | TRUE = logged in, FALSE = logged out. Stops push to logged-out devices |
| `registered_at` | When this device first logged in. Never changes |
| `last_seen_at` | Updated every API call. Shows you which devices are still being used |


### Why `ON DELETE CASCADE`?

```sql
FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
```
This means: if Raj deletes his account, MySQL automatically deletes all his
device rows too. Without this you would have orphaned rows pointing to a
user that no longer exists.


### Why Index:

```sql
CREATE INDEX idx_devices_user_id ON user_devices(user_id);
CREATE INDEX idx_devices_fcm     ON user_devices(fcm_token);
```

`user_id` index - every time you load the active sessions screen or send a
push alert, you query `WHERE user_id = ?`. Without an index, MySQL scans every
row in the table. With an index it jumps straight to the right rows.

`fcm_token` index - the Alerts Service looks up FCM tokens constantly whenever
an alert fires. This makes that lookup instant regardless of how many devices
are registered.

---

## How they connect

```
users table                     user_devices table

id=1  Raj Kumar          id=1  user_id=1  Samsung S24   ANDROID
                         id=2  user_id=1  MacBook       WEB
                         id=3  user_id=1  Wife iPhone   IOS

id=2  Sarah Chen         id=4  user_id=2  Samsung A54   ANDROID
```

One user can own many devices.
Each device row has `user_id` pointing back to its owner.
If the user is deleted, all their device rows are deleted automatically.



## `refresh_tokens`

### What does it store?

One row per refresh token issued. Every time a user logs in on a device, a
refresh token is created here. It is the key that lets users stay logged in
without re-entering their password.

### Real example

Raj is logged in on two devices:

| id | user_id | device_id | client_type | expires_at | revoked | revoke_reason |
|----|---------|-----------|-------------|------------|---------|---------------|
| 1 | 1 | 1 | ANDROID | 2026-08-14 | false | null |
| 2 | 1 | 2 | WEB | 2026-05-24 | false | null |
| 3 | 1 | 1 | ANDROID | 2026-02-01 | true | LOGOUT |

Row 3 is Raj's old token from when he logged out in February — kept for audit
trail, not deleted. Row 1 is his current Android token (90 days). Row 2 is
his browser token (7 days).

### How it works day to day

```
Raj opens the Android app after 2 hours
  → access token (JWT) has expired
  → app sends: POST /api/auth/refresh  { token: "abc123..." }
  → Spring checks:  token exists? YES
                    revoked?      NO
                    expired?      NO
  → issues new access token (60 min)
  → updates last_used_at to NOW()
  → Raj sees the dashboard — never asked for password
```

### Create table SQL

```sql
CREATE TABLE IF NOT EXISTS refresh_tokens (
    id            BIGINT AUTO_INCREMENT        PRIMARY KEY,
    user_id       BIGINT                       NOT NULL,
    device_id     BIGINT,
    token         VARCHAR(512)                 NOT NULL UNIQUE,
    client_type   ENUM('WEB','ANDROID','IOS')  NOT NULL,
    expires_at    DATETIME                     NOT NULL,
    revoked       BOOLEAN                      NOT NULL DEFAULT FALSE,
    revoke_reason VARCHAR(50),
    created_at    DATETIME                     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_used_at  DATETIME,

    FOREIGN KEY (user_id)   REFERENCES users(id)        ON DELETE CASCADE,
    FOREIGN KEY (device_id) REFERENCES user_devices(id) ON DELETE SET NULL
);

CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_token   ON refresh_tokens(token);
```

### Why each column exists

| Column | Why |
|--------|-----|
| `user_id` | Which user this token belongs to |
| `device_id` | Which device issued this token — nullable because web sessions may not have a device row |
| `token` | Long random string (256-bit). `UNIQUE` ensures no two tokens are ever the same |
| `client_type` | Spring reads this to set expiry — WEB=7 days, ANDROID/IOS=90 days |
| `expires_at` | Hard expiry — even if not revoked, token is dead after this datetime |
| `revoked` | TRUE = token is invalid. Checked on every refresh request before anything else |
| `revoke_reason` | Why it was killed — `LOGOUT`, `EXPIRED`, `SECURITY_BREACH`, `NEW_LOGIN` |
| `created_at` | When this token was first issued |
| `last_used_at` | Updated every time token is used — shows active vs abandoned tokens |

### Why `ON DELETE SET NULL` for device_id?

```sql
FOREIGN KEY (device_id) REFERENCES user_devices(id) ON DELETE SET NULL
```

If a device row is deleted, `device_id` becomes null but the token row stays.
This preserves the audit trail -> you can still see the token existed and when
it was last used, even if the device record is gone.


`user_id` which uses `ON DELETE CASCADE` — if the user is deleted, all their
tokens are deleted too.


------------------


## `user_preferences`

### What does it store?

One row per user containing all their personal settings — notification
preferences, app theme, language, and whether they allow location tracking.
This is a 1:1 table with `users` — one user always has exactly one preference
record.

### Real example

| id | user_id | preferred_city | email_alerts | push_alerts | sms_alerts | alert_frequency | theme | language | location_sharing |
|----|---------|---------------|--------------|-------------|------------|-----------------|-------|----------|-----------------|
| 1 | 1 | Wellington | true | true | false | INSTANT | DARK | en | true |
| 2 | 2 | Auckland | true | false | false | DAILY | SYSTEM | mi | false |

Raj gets instant push alerts in dark mode. Sarah gets a daily email digest
in Te Reo Maori.

### Create table SQL

```sql
CREATE TABLE IF NOT EXISTS user_preferences (
    id               BIGINT AUTO_INCREMENT             PRIMARY KEY,
    user_id          BIGINT                            NOT NULL UNIQUE,
    preferred_city   VARCHAR(50),
    email_alerts     BOOLEAN                           NOT NULL DEFAULT TRUE,
    push_alerts      BOOLEAN                           NOT NULL DEFAULT TRUE,
    sms_alerts       BOOLEAN                           NOT NULL DEFAULT FALSE,
    alert_frequency  ENUM('INSTANT','HOURLY','DAILY')  NOT NULL DEFAULT 'INSTANT',
    theme            ENUM('LIGHT','DARK','SYSTEM')      NOT NULL DEFAULT 'SYSTEM',
    language         VARCHAR(10)                       NOT NULL DEFAULT 'en',
    updated_at       DATETIME                          NOT NULL DEFAULT CURRENT_TIMESTAMP
                                                                ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

### Why each column exists

| Column | Why |
|--------|-----|
| `user_id` | FK to `users.id` with `UNIQUE` — this single constraint enforces the 1:1 relationship |
| `preferred_city` | Overrides `users.city` for the dashboard. If null falls back to `users.city` |
| `email_alerts` | Master toggle for all email notifications |
| `push_alerts` | Master toggle for Firebase push to Android/iOS — checked before sending any push |
| `sms_alerts` | SMS alerts toggle — defaults false, future feature |
| `alert_frequency` | INSTANT = notify immediately, HOURLY = batch, DAILY = one digest per day |
| `theme` | LIGHT, DARK, or SYSTEM. Angular reads this on login and applies it immediately |
| `language` | `en` = English, `mi` = Te Reo Maori. NZ-specific — shows cultural awareness |
| `updated_at` | Refreshed on every settings save — useful for support and audit |

### Why a separate table and not columns on `users`?

Two reasons. First, preferences change far more often than identity data — a
user might toggle dark mode several times a day. Separating them means a
settings update never touches the `users` row. Second, it keeps `users` lean
and focused on identity only.

-------------------

## `user_sessions`

### What does it store?

One row per login event. Every time a user logs in — on any device or browser
— a new row is created here. It is your security audit trail and powers the
"active sessions" screen.

### Real example

| id | user_id | device_id | ip_address | platform | login_at | logout_at |
|----|---------|-----------|------------|----------|----------|-----------|
| 1 | 1 | 1 | 203.118.42.5 | ANDROID | 2026-03-01 08:00 | null |
| 2 | 1 | 2 | 203.118.42.5 | WEB | 2026-05-10 09:00 | 2026-05-10 17:30 |
| 3 | 1 | null | 185.220.101.9 | WEB | 2026-05-15 02:14 | null |

Row 1 — Android session, still active (logout_at is null).
Row 2 — Browser session, cleanly logged out same day.
Row 3 — Login from a completely different IP at 2am — this triggers the
"new login detected" security alert. device_id is null because browsers
do not always have a registered device row.

### Create table SQL

```sql
CREATE TABLE IF NOT EXISTS user_sessions (
    id           BIGINT AUTO_INCREMENT           PRIMARY KEY,
    user_id      BIGINT                          NOT NULL,
    device_id    BIGINT,
    ip_address   VARCHAR(45)                     NOT NULL,
    user_agent   VARCHAR(500),
    platform     ENUM('WEB','ANDROID','IOS')     NOT NULL,
    login_at     DATETIME                        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen_at DATETIME                        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                                          ON UPDATE CURRENT_TIMESTAMP,
    logout_at    DATETIME,

    FOREIGN KEY (user_id)   REFERENCES users(id)        ON DELETE CASCADE,
    FOREIGN KEY (device_id) REFERENCES user_devices(id) ON DELETE SET NULL
);

CREATE INDEX idx_sessions_user_id  ON user_sessions(user_id);
CREATE INDEX idx_sessions_login_at ON user_sessions(login_at);
```

### Why each column exists

| Column | Why |
|--------|-----|
| `user_id` | Which user logged in |
| `device_id` | Which registered device — nullable for browser logins with no device row |
| `ip_address` | IP of the login. VARCHAR(45) covers both IPv4 and full IPv6 addresses |
| `user_agent` | Raw browser or app string — e.g. `CityPulse-Android/1.0.3`. Nullable in case it is missing |
| `platform` | WEB, ANDROID, IOS — cleaner than parsing user_agent every time |
| `login_at` | When the session started. Set once, never changed |
| `last_seen_at` | Updated on every API call in this session — shows if session is still being used |
| `logout_at` | NULL = session still active. Set on clean logout. Stays NULL if token simply expires |



---------------------------


## `password_reset_tokens`

### What does it store?

One row per password reset request. Every time a user clicks "Forgot
password?" a new row is created with a 6-digit OTP (One Time Password)
that gets emailed to them as a plain code — never in a URL.

### Why OTP instead of a URL token?

A URL token exposes the credential in browser history, server logs, and
referrer headers. A 6-digit OTP is typed manually into a form and submitted
via POST body — it never appears in any URL, ever. This is the same approach
NZ banks like ANZ and ASB use.

The OTP itself is never stored — only its SHA-256 hash is saved. Even if
the database is breached, the attacker cannot reverse the hash back to
the 6-digit code.

### How the full flow works

```
1. User clicks "Forgot password?" and enters their email
2. Spring generates a 6-digit OTP e.g. 847291
3. Spring SHA-256 hashes it → saves the hash here with 15 min expiry
4. Spring emails the plain code

   Subject: CityPulse password reset
   Your reset code is: 847291
   This code expires in 15 minutes.
   Never share this code with anyone.

5. User opens Angular reset page manually or via plain link
6. User types: email + 847291 + new password + confirm password
7. Angular: POST /api/auth/reset-password
   body: { email: "raj@gmail.com", otp: "847291", newPassword: "..." }
8. Spring hashes submitted OTP → compares to stored otp_hash → match
9. Spring updates users.password with BCrypt hash of new password
10. Spring sets used=TRUE, used_at=NOW()
11. User logs in with new password — OTP never appeared in any URL
```

### Real example

| id | user_id | otp_hash | expires_at | used | used_at |
|----|---------|----------|------------|------|---------|
| 1 | 1 | e3b0c442... | 2026-05-16 09:15 | true | 2026-05-16 09:08 |
| 2 | 1 | a87ff679... | 2026-05-16 10:30 | false | null |

Row 1 — used and consumed. The hash is stored, never the plain OTP.
Row 2 — currently active, 15 minutes not yet passed.

### Create table SQL

```sql
CREATE TABLE IF NOT EXISTS password_reset_tokens (
    id         BIGINT AUTO_INCREMENT  PRIMARY KEY,
    user_id    BIGINT                 NOT NULL,
    otp_hash   VARCHAR(255)           NOT NULL,
    expires_at DATETIME               NOT NULL,
    used       BOOLEAN                NOT NULL DEFAULT FALSE,
    created_at DATETIME               NOT NULL DEFAULT CURRENT_TIMESTAMP,
    used_at    DATETIME,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX idx_prt_user_id ON password_reset_tokens(user_id);
```

### Why each column exists

| Column | Why |
|--------|-----|
| `user_id` | Which user requested the reset |
| `otp_hash` | SHA-256 hash of the 6-digit OTP. Raw OTP is never stored anywhere |
| `expires_at` | 15 minutes from creation — short window limits attack surface |
| `used` | TRUE once consumed — prevents reusing the same OTP twice |
| `created_at` | When reset was requested — used for rate limiting (max 3 per hour per user) |
| `used_at` | When OTP was consumed — useful for support and audit trail |

---

## 6 tables connection

```
users (1)
  │
  ├── (many)  user_devices    one user, many devices
  │               │
  │               ├── (many)  refresh_tokens    one device, many refesh_tokens
  │               └── (many)  user_sessions     one device, many user_sessions
  │
  ├── (1)     user_preferences       one user, one settings record
  ├── (many)  refresh_tokens         all tokens across all devices
  ├── (many)  user_sessions          all sessions across all devices
  └── (many)  password_reset_tokens  all reset attempts
```

All foreign keys use ON DELETE CASCADE — deleting a user automatically
cleans up every row across all 6 tables. No orphaned data ever.

---