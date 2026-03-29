package com.oracle.solarmetrics.domains;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@With
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "SM_SISTEMA")
public class Sistema {

    @Id
    @Column(name = "ID_SISTEMA", length = 36)
    @GeneratedValue(strategy = GenerationType.UUID)
    private String id;

    @Column(name = "NOME_INSTALACAO", nullable = false, length = 200)
    private String nomeInstalacao;

    @Column(name = "DATA_INSTALACAO", nullable = false)
    private LocalDate dataInstalacao;

    @Column(name = "POTENCIA_TOTAL", nullable = false, precision = 12, scale = 2)
    private BigDecimal potenciaTotal;

    @Column(name = "STATUS", nullable = false, length = 50)
    private String status;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "SM_USUARIO_ID_USER", nullable = false)
    private Cliente cliente;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "SM_END_SISTEMA_ID_END_SIS", nullable = false)
    private EnderecoSistema endereco;

    @OneToMany(mappedBy = "sistema", fetch = FetchType.LAZY, cascade = CascadeType.ALL)
    @Builder.Default
    private List<PainelSolar> painelSolar = new ArrayList<>();

    @OneToMany(mappedBy = "sistema", fetch = FetchType.LAZY, cascade = CascadeType.ALL)
    @Builder.Default
    private List<Sensor> sensor = new ArrayList<>();
}
