# Amostras de JSON para testes de API (CRUD)

Substitua `BASE_JAVA` e `BASE_NET` pelas URLs reais dos Web Apps (ex.: `https://solarmetrics-java-seuRM.azurewebsites.net`).

Relacionamento entre tabelas (exemplo de demonstração): **`SM_SISTEMA.CLIENTE_ID` referencia `SM_USUARIO.ID`**. Crie primeiro um cliente, use o `id` retornado ao criar um sistema.

## Java (Spring) — `BASE_JAVA`

| Operação | Método | Caminho | Observação |
|----------|--------|---------|------------|
| Incluir cliente | POST | `/cliente` | Corpo: [`java-post-cliente.json`](java-post-cliente.json) |
| Consultar cliente | GET | `/cliente/{id}` | Requer autenticação (roles) conforme API |
| Alterar cliente | PUT | `/cliente` | Corpo: [`java-put-cliente.json`](java-put-cliente.json) |
| Excluir cliente | DELETE | `/cliente/{id}` | — |
| Incluir sistema | POST | `/sistema` | Corpo: [`java-post-sistema.json`](java-post-sistema.json) — use `clienteId` do cliente criado |

Os endpoints `/sistema` exigem **JWT** com papel `ADMIN` ou `USUARIO` (exceto fluxos públicos de cadastro de cliente, conforme a API). Obtenha o token via fluxo de autenticação do Spring Security (login) antes de chamar POST/PUT/GET em `/sistema`.

Swagger UI (quando habilitado): `BASE_JAVA/swagger-ui/index.html`.

## .NET — `BASE_NET`

Rotas baseadas no nome do controller: **`/Cliente`**. A maioria dos endpoints exige **Bearer JWT** — obtenha o token conforme o [README do repositório .NET](https://github.com/bmvck/SolarMetrics-Dotnet) (ex.: `POST /auth/token` em ambientes não produtivos, se disponível).

| Operação | Método | Caminho | Corpo de exemplo |
|----------|--------|---------|-------------------|
| Incluir | POST | `/Cliente` | [`dotnet-post-cliente.json`](dotnet-post-cliente.json) |
| Consultar | GET | `/Cliente/{id}` | — |
| Alterar | PUT | `/Cliente` | [`dotnet-put-cliente.json`](dotnet-put-cliente.json) |
| Excluir | DELETE | `/Cliente/{id}` | — |

## cURL (exemplo)

```bash
curl -sS -X POST "$BASE_JAVA/cliente" \
  -H "Content-Type: application/json" \
  -d @java-post-cliente.json
```

Após criar o cliente, copie o `id` da resposta para `java-post-sistema.json` no campo `clienteId`.
