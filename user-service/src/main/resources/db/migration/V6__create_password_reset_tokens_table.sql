CREATE TABLE IF NOT EXISTS password_reset_tokens (
                                                     id         BIGINT       AUTO_INCREMENT PRIMARY KEY,
                                                     user_id    BIGINT       NOT NULL,
                                                     otp_hash   VARCHAR(255) NOT NULL,
    expires_at DATETIME     NOT NULL,
    used       BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    used_at    DATETIME,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );

CREATE INDEX idx_prt_user_id ON password_reset_tokens(user_id);