
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
