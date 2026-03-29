package com.oracle.solarmetrics.gateways;

import com.oracle.solarmetrics.domains.Cliente;
import com.oracle.solarmetrics.gateways.dtos.response.ClienteResponseDto;
import com.oracle.solarmetrics.services.ClienteService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.Mockito;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;

import static org.junit.jupiter.api.Assertions.*;

@ExtendWith(MockitoExtension.class)
class ClienteControllerTest {

    @InjectMocks
    private ClienteController controller;

    @Mock
    private ClienteService service;

    @Test
    void testeController(){

        //AAA

        //Arange
        Cliente cliente = Cliente.builder()
                .id("12313jkjkj")
                .nome("Carlos")
                .email("carlos@gmail.com")
                .telefone("11972935394")
                .tipoUser("Residencial")
                .status("ATIVO")
                .build();

        String param = "sadajsdkad";

        Mockito.when(service.getId(param)).thenReturn(cliente);

        // Act
        ResponseEntity<ClienteResponseDto> resposta = controller.getId(param);

        // Assert
        assertEquals(resposta.getBody().nome(), cliente.getNome());
        Mockito.verify(service, Mockito.times(1)).getId(param);

    }

}