package com.nz.citypulse.userservice.entity;


import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.Id;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDateTime;

@Entity
@Table(name = "users")
@Data
@Builder // // Lombok's builder ignores the field's default value when building an object so use @Builder.Default
@NoArgsConstructor
@AllArgsConstructor
@EntityListeners(AuditingEntityListener.class)
public class User {


    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 100)
    private String name;

    @Column(nullable = false,unique = true, length = 150)
    private String email;

    @Column(nullable = false)
    private String password;

    @Enumerated(EnumType.STRING)
    @Builder.Default
    private Role role =  Role.USER;


    @Column(nullable = false)
    private String city;


    @Column(nullable = false)
    @Builder.Default
    private Boolean enabled = true;


    @CreatedDate
    @Column(updatable = false)
    private LocalDateTime createdAt;


    @LastModifiedDate
    private LocalDateTime updatedAt;


    public enum Role {
        USER, ADMIN
    }

}


//IDENTITY — tells JPA to use the database's own auto-increment. MySQL handles the ID itself, just like AUTO_INCREMENT in your SQL.

//@EnableJpaAuditing              → to turn on the feature
//@EntityListeners(Auditing...)   → tells JPA which listeners to attach to this specific entity.
//@CreatedDate / @LastModifiedDate → mark which fields should be filled automatically