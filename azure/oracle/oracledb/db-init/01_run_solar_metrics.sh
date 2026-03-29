#!/bin/bash
# Executa os scripts do repositório SolarMetrics-BancoDados na ordem do README oficial,
# depois ajustes de compatibilidade com a API Spring deste projeto.
set -euo pipefail

echo ">> SolarMetrics: baixando SQL do GitHub (bmvck/SolarMetrics-BancoDados)..."

BASE_URL="${SOLARMETRICS_SQL_BASE:-https://raw.githubusercontent.com/bmvck/SolarMetrics-BancoDados/main}"
TMP=/tmp/solar_metrics_sql
mkdir -p "$TMP"

fetch() {
  local name="$1"
  echo ">> curl $name"
  curl -fsSL "$BASE_URL/$name" -o "$TMP/$name"
}

fetch 01_DDL.sql
fetch 02_Dados.sql
fetch 04_Functions.sql
fetch 05_Procedures.sql
fetch 06_Triggers_Auditoria.sql

USER="${APP_USER:-GSUSER}"
PASS="${APP_USER_PASSWORD:-gspassword}"
PDB="${ORACLE_DATABASE:-GSDB}"

run_sql() {
  local file="$1"
  echo ">> sqlplus @ $(basename "$file")"
  sqlplus -s "${USER}/${PASS}@localhost/${PDB}" @"$file"
}

run_sql "$TMP/01_DDL.sql"
run_sql "$TMP/02_Dados.sql"
run_sql "$TMP/04_Functions.sql"
run_sql "$TMP/05_Procedures.sql"
run_sql "$TMP/06_Triggers_Auditoria.sql"

echo ">> Compatibilidade API Spring (TELEFONE / TIPO_USER em SM_USUARIO)"
sqlplus -s "${USER}/${PASS}@localhost/${PDB}" <<'EOSQL'
WHENEVER SQLERROR CONTINUE
ALTER TABLE SM_USUARIO ADD (TELEFONE VARCHAR2(20));
ALTER TABLE SM_USUARIO ADD (TIPO_USER VARCHAR2(50));
EOSQL

echo ">> SolarMetrics: carga inicial concluída."
