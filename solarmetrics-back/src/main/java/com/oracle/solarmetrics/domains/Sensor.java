package com.oracle.solarmetrics.domains;

import jakarta.persistence.*;
import lombok.*;

import java.util.ArrayList;
import java.util.List;

@With
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "SM_SENSOR")
public class Sensor {

    @Id
    @Column(name = "ID_SENSOR", length = 36)
    @GeneratedValue(strategy = GenerationType.UUID)
    private String id;

    @Column(name = "TIPO", nullable = false, length = 50)
    private String tipo;

    @Column(name = "STATUS", nullable = false, length = 50)
    private String status;

    @Column(name = "LOCALIZACAO", length = 200)
    private String localizacao;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "SM_SISTEMA_ID_SISTEMA", nullable = false)
    private Sistema sistema;

    @OneToMany(mappedBy = "sensor", fetch = FetchType.LAZY, cascade = CascadeType.ALL)
    @Builder.Default
    private List<Monitoramento> monitoramento = new ArrayList<>();
}
