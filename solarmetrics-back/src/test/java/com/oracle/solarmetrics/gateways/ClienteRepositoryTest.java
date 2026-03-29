package com.oracle.solarmetrics.gateways;

import com.oracle.solarmetrics.domains.Cliente;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

@DataJpaTest
class ClienteRepositoryTest {

    @Autowired
    private ClienteRepository clienteRepository;

    @Test
    void findById() {

        //AAA

        // Arange
        Cliente expected = Cliente.builder()
                .nome("Carlos Clementino")
                .email("carlos@gmail.com")
                .telefone("11972935394")
                .tipoUser("Residencial")
                .status("ATIVO")
                .build();

        Cliente resultadoSafe = clienteRepository.save(expected);

        //Act
        Optional<Cliente> actual = clienteRepository.findById(resultadoSafe.getId());

        //Assert
        assertTrue(actual.isPresent());
        assertEquals(resultadoSafe.getId(), actual.get().getId());
        assertEquals("Carlos Clementino", actual.get().getNome());


    }

    @Test
    void findByEmail() {

        //AAA

        // Arange
        String email = "carlos@gmail.com";

        Cliente cliente1 = Cliente.builder()
                .nome("Carlos Clementino")
                .email("carlos@gmail.com")
                .telefone("11972935394")
                .tipoUser("Residencial")
                .status("ATIVO")
                .build();

        Cliente cliente2 = Cliente.builder()
                .nome("Souza Lopez")
                .email("Souza@gmail.com")
                .telefone("11903904905")
                .tipoUser("Comercial")
                .status("ATIVO")
                .build();

        clienteRepository.saveAll(List.of(cliente1,cliente2));

        //Act
        Optional<Cliente> cliente = clienteRepository.findByEmail(email);

        //Assert
        Assertions.assertFalse(cliente.isEmpty());
        Assertions.assertEquals("Carlos Clementino",cliente.get().getNome());


    }

}