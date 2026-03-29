# Oracle para SolarMetrics

**Oracle XE 21** em Docker, com carga automática dos scripts do [SolarMetrics-BancoDados](https://github.com/bmvck/SolarMetrics-BancoDados).

## Conteúdo

| Arquivo / pasta | Função |
|-----------------|--------|
| `docker-compose.yml` | Serviço `oracledb` (`gvenzl/oracle-xe:21-slim`), volume persistente e montagem de `db-init`. |
| `oracledb/db-init/01_run_solar_metrics.sh` | Na **primeira** inicialização do volume, baixa via `curl` os `.sql` do GitHub e executa na ordem: 01 DDL → 02 Dados → 04–06 (Sprint 3); em seguida adiciona `TELEFONE` e `TIPO_USER` em `SM_USUARIO` para a API Spring. |

## Variáveis de ambiente (compose)

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `ORACLE_PASSWORD` | `gspassword` | Senha SYS/SYSTEM (somente laboratório). |
| `ORACLE_DATABASE` | `GSDB` | Nome do PDB / service name JDBC. |
| `APP_USER` | `GSUSER` | Usuário da aplicação. |
| `APP_USER_PASSWORD` | `gspassword` | Senha do usuário da aplicação. |
| `SOLARMETRICS_SQL_BASE` | URL raw GitHub | Troque para fork/espelho se o GitHub estiver indisponível. |

## Conexão JDBC (Spring / .NET)

- **Host:** IP público da VM Azure (ou nome DNS) — **não** commite senhas.
- **Porta:** `1521`
- **Service name:** valor de `ORACLE_DATABASE` (ex.: `GSDB`)
- **Usuário / senha:** `APP_USER` / `APP_USER_PASSWORD`

Exemplo Spring Boot:

`jdbc:oracle:thin:@//SEU_HOST:1521/GSDB`

## VM Azure (resumo)

1. Criar VM Linux (Ubuntu LTS), instalar Docker e Docker Compose.
2. Copiar esta pasta `azure/oracle` para a VM (ou clonar o repositório SolarMetrics-DevOps).
3. `cd azure/oracle && docker compose up -d`
4. No NSG, liberar **1521** apenas para origens confiáveis (ideal: IPs de saída dos App Services).

**Região:** provisione a VM no mesmo resource group/região do restante do projeto (**`eastus2`**), salvo exigência do enunciado.

Para **recriar** o banco do zero: `docker compose down -v` e subir de novo (os scripts em `db-init` rodam só com volume vazio).
