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