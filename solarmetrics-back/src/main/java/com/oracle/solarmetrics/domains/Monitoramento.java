package com.oracle.solarmetrics.domains;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@With
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "SM_MONITORAMENTO")
public class Monitoramento {

    @Id
    @Column(name = "ID_MONITORAMENTO", length = 36)
    @GeneratedValue(strategy = GenerationType.UUID)
    private String id;

    @Column(name = "DATA_HORA", nullable = false)
    private LocalDateTime dataHora;

    @Column(name = "VALOR_LEITURA", nullable = false, precision = 14, scale = 4)
    private BigDecimal valorLeitura;

    @Column(name = "UNIDADE", nullable = false, length = 20)
    private String unidade;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "SM_SENSOR_ID_SENSOR", nullable = false)
    private Sensor sensor;
}
