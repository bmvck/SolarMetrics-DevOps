package com.oracle.solarmetrics.domains;

import jakarta.persistence.*;
import lombok.*;

import java.util.ArrayList;
import java.util.List;

@With
@Getter
@Setter
@Builder(toBuilder = true)
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "SM_USUARIO")
public class Cliente {

    @Id
    @Column(name = "ID_USER", length = 36)
    @GeneratedValue(strategy = GenerationType.UUID)
    private String id;

    @Column(name = "NOME_COMPLETO", nullable = false, length = 200)
    private String nome;

    @Column(name = "EMAIL", nullable = false, length = 200, unique = true)
    private String email;

    @Column(name = "SENHA_HASH", length = 200)
    private String senhaHash;

    @Column(name = "STATUS", nullable = false, length = 20)
    private String status;

    @Column(name = "TELEFONE", length = 20)
    private String telefone;

    @Column(name = "TIPO_USER", length = 50)
    private String tipoUser;

    @OneToMany(mappedBy = "cliente", fetch = FetchType.LAZY, cascade = CascadeType.ALL)
    @Builder.Default
    private List<Sistema> sistemas = new ArrayList<>();
}
