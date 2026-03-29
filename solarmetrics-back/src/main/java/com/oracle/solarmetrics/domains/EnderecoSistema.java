package com.oracle.solarmetrics.domains;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.*;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "SM_END_SISTEMA")
public class EnderecoSistema {

    @Id
    @Column(name = "ID_END_SIS", length = 36)
    private String id;

    @Column(name = "LOGRADOURO", nullable = false, length = 200)
    private String logradouro;

    @Column(name = "CIDADE", nullable = false, length = 100)
    private String cidade;

    @Column(name = "UF", nullable = false, length = 2)
    private String uf;

    @Column(name = "CEP", length = 12)
    private String cep;
}
