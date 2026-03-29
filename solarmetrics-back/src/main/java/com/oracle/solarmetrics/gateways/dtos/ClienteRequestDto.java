package com.oracle.solarmetrics.gateways.dtos;

import com.oracle.solarmetrics.domains.Cliente;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import lombok.Data;

@Data
public class ClienteRequestDto {

    @NotBlank
    @NotNull
    @Email(message = "Formato de e-mail inválido")
    private String email;
    @NotBlank
    @NotNull
    private String nome;
    @Pattern(regexp = "\\d{11}", message = "O celular deve conter exatamente 11 dígitos numéricos")
    private String telefone;
    @NotBlank
    @NotNull
    private String tipoUser;

    public Cliente toCliente() {
        return Cliente.builder()
                .email(email)
                .nome(nome)
                .telefone(telefone)
                .tipoUser(tipoUser)
                .status("ATIVO")
                .build();
    }
}
