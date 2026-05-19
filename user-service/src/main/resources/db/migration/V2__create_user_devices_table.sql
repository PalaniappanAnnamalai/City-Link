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