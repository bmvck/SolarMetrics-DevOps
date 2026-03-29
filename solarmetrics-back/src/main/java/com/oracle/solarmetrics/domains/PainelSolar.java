package com.oracle.solarmetrics.domains;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;

@With
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "SM_PAINEL_SOLAR")
public class PainelSolar {

    @Id
    @Column(name = "ID_PAINEL", length = 36)
    @GeneratedValue(strategy = GenerationType.UUID)
    private String id;

    @Column(name = "MODELO", nullable = false, length = 100)
    private String modelo;

    @Column(name = "CAPACIDADE_KWP", nullable = false, precision = 10, scale = 2)
    private BigDecimal capacidadeKwp;

    @Column(name = "QTD_PANEIS", nullable = false)
    private Integer qtdPaneis;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "SM_SISTEMA_ID_SISTEMA", nullable = false)
    private Sistema sistema;
}
