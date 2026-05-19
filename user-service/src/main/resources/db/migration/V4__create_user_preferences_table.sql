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