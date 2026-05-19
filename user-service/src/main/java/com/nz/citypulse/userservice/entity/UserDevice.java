package com.nz.citypulse.userservice.entity;


import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(name = "user_devices")
@Data
@Builder // // Lombok's builder ignores the field's default value when building an object so use @Builder.Default
@NoArgsConstructor
@AllArgsConstructor
public class UserDevice {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false, unique = true)
    private String deviceFingerprint;

    private String deviceName;

    private String deviceModel;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private OsType osType;

    private String osVersion;

    private String appVersion;

    private String fcmToken;

    @Column(nullable = false)
    @Builder.Default
    private Boolean isActive = true;

    @Column(nullable = false, updatable = false)
    @Builder.Default
    private LocalDateTime registeredAt = LocalDateTime.now();

    @Builder.Default
    private LocalDateTime lastSeenAt = LocalDateTime.now();

    public enum OsType {
        ANDROID, IOS, WEB
    }
}
