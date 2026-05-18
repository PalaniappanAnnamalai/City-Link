-- ============================================================
--  CityPulse NZ — User Flow Database Schema
--  Run this file in MySQL Workbench or MySQL terminal
--  Order matters — do not change the sequence
-- ============================================================

CREATE DATABASE IF NOT EXISTS citypulse_users
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE citypulse_users;

-- ============================================================
--  TABLE 1: users
--  Core identity table — every other table points to this one
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
    id          BIGINT          AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(100)    NOT NULL,
    email       VARCHAR(150)    NOT NULL UNIQUE,
    password    VARCHAR(255)    NOT NULL,
    role        ENUM('USER','ADMIN') NOT NULL DEFAULT 'USER',
    city        VARCHAR(50)     DEFAULT 'Auckland',
    enabled     BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                ON UPDATE CURRENT_TIMESTAMP
);

-- ============================================================
--  TABLE 2: user_devices
--  Every device a user logs in from (Android, iOS, browser)
-- ============================================================
CREATE TABLE IF NOT EXISTS user_devices (
    id                  BIGINT      AUTO_INCREMENT PRIMARY KEY,
    user_id             BIGINT      NOT NULL,
    device_fingerprint  VARCHAR(255) NOT NULL UNIQUE,
    device_name         VARCHAR(150),
    device_model        VARCHAR(100),
    os_type             ENUM('ANDROID','IOS','WEB') NOT NULL,
    os_version          VARCHAR(50),
    app_version         VARCHAR(20),
    fcm_token           VARCHAR(512),
    is_active           BOOLEAN     NOT NULL DEFAULT TRUE,
    registered_at       DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen_at        DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX idx_user_devices_user_id ON user_devices(user_id);
CREATE INDEX idx_user_devices_fcm     ON user_devices(fcm_token);

-- ============================================================
--  TABLE 3: refresh_tokens
--  JWT refresh tokens — one per device per login
--  WEB = 7 days expiry, ANDROID/IOS = 90 days expiry
-- ============================================================
CREATE TABLE IF NOT EXISTS refresh_tokens (
    id            BIGINT      AUTO_INCREMENT PRIMARY KEY,
    user_id       BIGINT      NOT NULL,
    device_id     BIGINT,
    token         VARCHAR(512) NOT NULL UNIQUE,
    client_type   ENUM('WEB','ANDROID','IOS') NOT NULL,
    expires_at    DATETIME    NOT NULL,
    revoked       BOOLEAN     NOT NULL DEFAULT FALSE,
    revoke_reason VARCHAR(50),
    created_at    DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_used_at  DATETIME,

    FOREIGN KEY (user_id)   REFERENCES users(id)        ON DELETE CASCADE,
    FOREIGN KEY (device_id) REFERENCES user_devices(id) ON DELETE SET NULL
);

CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_token   ON refresh_tokens(token);

-- ============================================================
--  TABLE 4: user_preferences
--  One row per user — notification settings, theme, language
--  user_id is UNIQUE to enforce 1:1 with users
-- ============================================================
CREATE TABLE IF NOT EXISTS user_preferences (
    id               BIGINT      AUTO_INCREMENT PRIMARY KEY,
    user_id          BIGINT      NOT NULL UNIQUE,
    preferred_city   VARCHAR(50),
    email_alerts     BOOLEAN     NOT NULL DEFAULT TRUE,
    push_alerts      BOOLEAN     NOT NULL DEFAULT TRUE,
    sms_alerts       BOOLEAN     NOT NULL DEFAULT FALSE,
    alert_frequency  ENUM('INSTANT','HOURLY','DAILY') NOT NULL DEFAULT 'INSTANT',
    theme            ENUM('LIGHT','DARK','SYSTEM')     NOT NULL DEFAULT 'SYSTEM',
    language         VARCHAR(10) NOT NULL DEFAULT 'en',
    updated_at       DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP
                                 ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ============================================================
--  TABLE 5: user_sessions
--  Audit trail of every login — powers the active sessions screen
-- ============================================================
CREATE TABLE IF NOT EXISTS user_sessions (
    id           BIGINT      AUTO_INCREMENT PRIMARY KEY,
    user_id      BIGINT      NOT NULL,
    device_id    BIGINT,
    ip_address   VARCHAR(45) NOT NULL,
    user_agent   VARCHAR(500),
    platform     ENUM('WEB','ANDROID','IOS') NOT NULL,
    login_at     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP
                             ON UPDATE CURRENT_TIMESTAMP,
    logout_at    DATETIME,

    FOREIGN KEY (user_id)   REFERENCES users(id)        ON DELETE CASCADE,
    FOREIGN KEY (device_id) REFERENCES user_devices(id) ON DELETE SET NULL
);

CREATE INDEX idx_sessions_user_id  ON user_sessions(user_id);
CREATE INDEX idx_sessions_login_at ON user_sessions(login_at);

-- ============================================================
--  TABLE 6: password_reset_tokens
--  OTP-based password reset — 6 digit code emailed to user
--  otp_hash stores SHA-256 hash of the code, never the raw OTP
-- ============================================================
CREATE TABLE IF NOT EXISTS password_reset_tokens (
    id         BIGINT      AUTO_INCREMENT PRIMARY KEY,
    user_id    BIGINT      NOT NULL,
    otp_hash   VARCHAR(255) NOT NULL,
    expires_at DATETIME    NOT NULL,
    used       BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    used_at    DATETIME,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX idx_prt_user_id ON password_reset_tokens(user_id);

-- ============================================================
--  Verify all tables created successfully
-- ============================================================
SHOW TABLES;
