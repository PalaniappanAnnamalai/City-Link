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