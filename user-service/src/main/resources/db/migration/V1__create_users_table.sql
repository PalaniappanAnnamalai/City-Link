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