#!/usr/bin/env bash
#
# SolarMetrics — infra Azure + código-fonte via Internet + build + deploy (zip com wallet Oracle)
# Modo recomendado: Azure Cloud Shell (Bash) — tem az, curl, tar, unzip, zip, sem depender de pastas no seu PC.
#
# Wallet: use WALLET_URL (HTTPS) para o .zip do Oracle — ex.: Blob Storage com SAS, ou URL pública acadêmica.
#         Se não definir URL e existir o arquivo local em step-by-step-cloud/, esse arquivo é usado (dev local).
#
# Sem GitHub Actions. Execução: chmod +x deploy-azure-solarmetrics.sh && ./deploy-azure-solarmetrics.sh
#
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# ---------------------------------------------------------------------------
# Parâmetros
# ---------------------------------------------------------------------------
export AZURE_SUBSCRIPTION="${AZURE_SUBSCRIPTION:-Azure for Students}"
export RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:-rg-solarmetrics-cloud}"
export LOCATION="${LOCATION:-eastus2}"

export APP_INSIGHTS_NAME="${APP_INSIGHTS_NAME:-ai-solarmetrics}"
export APP_SERVICE_PLAN_NAME="${APP_SERVICE_PLAN_NAME:-plan-solarmetrics-linux}"
export APP_SERVICE_SKU="${APP_SERVICE_SKU:-B1}"

export WEBAPP_JAVA_NAME="${WEBAPP_JAVA_NAME:-solarmetrics-java}"
export WEBAPP_DOTNET_NAME="${WEBAPP_DOTNET_NAME:-solarmetrics-api}"
# Front-end MVC (SolarMetrics.Web) — mesmo plano App Service
export WEBAPP_WEB_NAME="${WEBAPP_WEB_NAME:-solarmetrics-web}"

export RABBITMQ_CONTAINER_NAME="${RABBITMQ_CONTAINER_NAME:-aci-solarmetrics-rabbitmq}"
export RABBITMQ_DNS_LABEL="${RABBITMQ_DNS_LABEL:-solarmetrics-rmq}"

export MONGO_CONTAINER_NAME="${MONGO_CONTAINER_NAME:-aci-solarmetrics-mongodb}"
export MONGO_DNS_LABEL="${MONGO_DNS_LABEL:-solarmetrics-mongo}"
export MONGO_USER="${MONGO_USER:-admin}"
export MONGO_PASSWORD="${MONGO_PASSWORD:-SolarMetricsMongo1}"
export MONGO_DATABASE_NAME="${MONGO_DATABASE_NAME:-solarmetrics}"
export MONGO_COLLECTION="${MONGO_COLLECTION:-chatbot_interactions}"

# Repositórios públicos (.git — usados para montar URL do tarball GitHub)
export GIT_URL_JAVA="${GIT_URL_JAVA:-https://github.com/ARC-ceo/SolarMetrics-JavaAdvanced.git}"
export GIT_URL_DOTNET="${GIT_URL_DOTNET:-https://github.com/bmvck/SolarMetrics-Dotnet.git}"
export GIT_BRANCH="${GIT_BRANCH:-main}"

# 1) WALLET_URL — preferido na nuvem: HTTPS para o Wallet_*.zip (Blob, link público temporário, etc.)
# 2) WALLET_ZIP — caminho local OU URL https (tratado como download)
# 3) Arquivo padrão ao lado do script, se existir (apenas máquina local com repo DevOps)
export WALLET_URL="${WALLET_URL:-}"
export WALLET_ZIP="${WALLET_ZIP:-}"

export DEPLOY_WORK_DIR="${DEPLOY_WORK_DIR:-}"

export ORACLE_USER="${ORACLE_USER:-ADMIN}"
export ORACLE_PASSWORD="${ORACLE_PASSWORD:-SolarMetrics1}"
export ORACLE_SERVICE_TNS="${ORACLE_SERVICE_TNS:-tad4hz13pj8xyhaw_high}"
export ORACLE_WALLET_DIR="${ORACLE_WALLET_DIR:-/home/site/wwwroot/wallet}"

export ORACLE_JDBC_URL="${ORACLE_JDBC_URL:-jdbc:oracle:thin:@(description=(retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=adb.sa-saopaulo-1.oraclecloud.com))(connect_data=(service_name=tad4hz13pj8xyhaw_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=yes)))}"

export JWT_KEY="${JWT_KEY:-SolarMetrics_Dev_Only_Change_In_Production_32Chars!!}"

# Use git clone em vez de tarball (mais lento; exige git). Padrão: 0 = tarball via curl (melhor para Cloud Shell)
export USE_GIT_CLONE="${USE_GIT_CLONE:-0}"

# ---------------------------------------------------------------------------
# Validação mínima
# ---------------------------------------------------------------------------
if [[ -z "${ORACLE_PASSWORD}" ]]; then
  echo "ERRO: ORACLE_PASSWORD vazio." >&2
  exit 1
fi

echo ">> Web Apps: ${WEBAPP_JAVA_NAME} | API ${WEBAPP_DOTNET_NAME} | Web ${WEBAPP_WEB_NAME} | Rabbit: ${RABBITMQ_DNS_LABEL} | Mongo: ${MONGO_DNS_LABEL}"
if [[ -n "${WALLET_URL}" ]]; then
  echo ">> Wallet: download via WALLET_URL (nuvem/HTTP)"
elif [[ -n "${WALLET_ZIP}" ]]; then
  echo ">> Wallet: WALLET_ZIP=${WALLET_ZIP}"
else
  echo ">> Wallet: arquivo local padrão (se existir) ou defina WALLET_URL"
fi

# ---------------------------------------------------------------------------
# Assinatura Azure
# ---------------------------------------------------------------------------
if [[ -n "${AZURE_SUBSCRIPTION}" ]]; then
  echo ">> Definindo assinatura: ${AZURE_SUBSCRIPTION}"
  az account set --subscription "${AZURE_SUBSCRIPTION}"
fi

echo ">> Conta ativa:"
az account show --query "{name:name, id:id}" -o table

# ---------------------------------------------------------------------------
# Resource group
# ---------------------------------------------------------------------------
echo ">> Criando resource group (idempotente)..."
az group create --name "${RESOURCE_GROUP_NAME}" --location "${LOCATION}" --output none

# ---------------------------------------------------------------------------
# Application Insights
# ---------------------------------------------------------------------------
if ! az monitor app-insights component show \
  --app "${APP_INSIGHTS_NAME}" \
  --resource-group "${RESOURCE_GROUP_NAME}" \
  &>/dev/null; then
  echo ">> Criando Application Insights..."
  az monitor app-insights component create \
    --app "${APP_INSIGHTS_NAME}" \
    --location "${LOCATION}" \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --application-type web \
    --output none
else
  echo ">> Application Insights já existe: ${APP_INSIGHTS_NAME}"
fi

APPINSIGHTS_CONNECTION_STRING="$(
  az monitor app-insights component show \
    --app "${APP_INSIGHTS_NAME}" \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --query connectionString \
    -o tsv
)"

# ---------------------------------------------------------------------------
# App Service Plan (Linux)
# ---------------------------------------------------------------------------
if ! az appservice plan show --name "${APP_SERVICE_PLAN_NAME}" --resource-group "${RESOURCE_GROUP_NAME}" &>/dev/null; then
  echo ">> Criando App Service Plan (${APP_SERVICE_SKU})..."
  az appservice plan create \
    --name "${APP_SERVICE_PLAN_NAME}" \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --location "${LOCATION}" \
    --sku "${APP_SERVICE_SKU}" \
    --is-linux \
    --output none
else
  echo ">> App Service Plan já existe: ${APP_SERVICE_PLAN_NAME}"
fi

# ---------------------------------------------------------------------------
# RabbitMQ (ACI)
# ---------------------------------------------------------------------------
if ! az container show --name "${RABBITMQ_CONTAINER_NAME}" --resource-group "${RESOURCE_GROUP_NAME}" &>/dev/null; then
  echo ">> Criando RabbitMQ (ACI) — imagem rabbitmq:3-management..."
  az container create \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --location "${LOCATION}" \
    --name "${RABBITMQ_CONTAINER_NAME}" \
    --image rabbitmq:3-management \
    --os-type Linux \
    --dns-name-label "${RABBITMQ_DNS_LABEL}" \
    --ports 5672 15672 \
    --cpu 1 \
    --memory 1.5 \
    --environment-variables \
      RABBITMQ_DEFAULT_USER=admin \
      RABBITMQ_DEFAULT_PASS=admin \
      RABBITMQ_DEFAULT_VHOST=email \
    --output none
else
  echo ">> Container RabbitMQ já existe: ${RABBITMQ_CONTAINER_NAME}"
fi

RABBIT_FQDN="$(
  az container show \
    --name "${RABBITMQ_CONTAINER_NAME}" \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --query "ipAddress.fqdn" \
    -o tsv
)"
if [[ -z "${RABBIT_FQDN}" ]]; then
  echo "ERRO: FQDN do RabbitMQ vazio." >&2
  exit 1
fi
echo ">> RabbitMQ: ${RABBIT_FQDN}:5672 (vhost=email)"

# ---------------------------------------------------------------------------
# MongoDB (ACI) — histórico do chatbot (.NET API + MVC)
# ---------------------------------------------------------------------------
if ! az container show --name "${MONGO_CONTAINER_NAME}" --resource-group "${RESOURCE_GROUP_NAME}" &>/dev/null; then
  echo ">> Criando MongoDB (ACI) — imagem mongo:7..."
  az container create \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --location "${LOCATION}" \
    --name "${MONGO_CONTAINER_NAME}" \
    --image mongo:7 \
    --os-type Linux \
    --dns-name-label "${MONGO_DNS_LABEL}" \
    --ports 27017 \
    --cpu 1 \
    --memory 1.5 \
    --environment-variables \
      MONGO_INITDB_ROOT_USERNAME="${MONGO_USER}" \
      MONGO_INITDB_ROOT_PASSWORD="${MONGO_PASSWORD}" \
    --output none
else
  echo ">> Container MongoDB já existe: ${MONGO_CONTAINER_NAME}"
fi

MONGO_FQDN="$(
  az container show \
    --name "${MONGO_CONTAINER_NAME}" \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --query "ipAddress.fqdn" \
    -o tsv
)"
if [[ -z "${MONGO_FQDN}" ]]; then
  echo "ERRO: FQDN do MongoDB vazio." >&2
  exit 1
fi
MONGO_CONN="mongodb://${MONGO_USER}:${MONGO_PASSWORD}@${MONGO_FQDN}:27017/?authSource=admin"
echo ">> MongoDB: ${MONGO_FQDN}:27017 (db=${MONGO_DATABASE_NAME})"

# ---------------------------------------------------------------------------
# Web Apps
# ---------------------------------------------------------------------------
if ! az webapp show --name "${WEBAPP_JAVA_NAME}" --resource-group "${RESOURCE_GROUP_NAME}" &>/dev/null; then
  echo ">> Criando Web App Java 17..."
  az webapp create \
    --name "${WEBAPP_JAVA_NAME}" \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --plan "${APP_SERVICE_PLAN_NAME}" \
    --runtime "JAVA:17-java17" \
    --output none
else
  echo ">> Web App Java já existe: ${WEBAPP_JAVA_NAME}"
fi

if ! az webapp show --name "${WEBAPP_DOTNET_NAME}" --resource-group "${RESOURCE_GROUP_NAME}" &>/dev/null; then
  echo ">> Criando Web App .NET 8..."
  az webapp create \
    --name "${WEBAPP_DOTNET_NAME}" \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --plan "${APP_SERVICE_PLAN_NAME}" \
    --runtime "DOTNETCORE:8.0" \
    --output none
else
  echo ">> Web App .NET já existe: ${WEBAPP_DOTNET_NAME}"
fi

if ! az webapp show --name "${WEBAPP_WEB_NAME}" --resource-group "${RESOURCE_GROUP_NAME}" &>/dev/null; then
  echo ">> Criando Web App .NET 8 (SolarMetrics.Web / MVC)..."
  az webapp create \
    --name "${WEBAPP_WEB_NAME}" \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --plan "${APP_SERVICE_PLAN_NAME}" \
    --runtime "DOTNETCORE:8.0" \
    --output none
else
  echo ">> Web App MVC já existe: ${WEBAPP_WEB_NAME}"
fi

for APP_NAME in "${WEBAPP_JAVA_NAME}" "${WEBAPP_DOTNET_NAME}" "${WEBAPP_WEB_NAME}"; do
  echo ">> Habilitando SCM básica em ${APP_NAME}..."
  az resource update \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --namespace Microsoft.Web \
    --resource-type basicPublishingCredentialsPolicies \
    --parent sites/"${APP_NAME}" \
    --name scm \
    --set properties.allow=true \
    --output none
done

DOTNET_ORACLE_CONN="User Id=${ORACLE_USER};Password=${ORACLE_PASSWORD};Data Source=${ORACLE_SERVICE_TNS};Wallet_Location=${ORACLE_WALLET_DIR};Tns_Admin=${ORACLE_WALLET_DIR};"
DOTNET_API_PUBLIC_URL="https://${WEBAPP_DOTNET_NAME}.azurewebsites.net"

echo ">> Application Settings (Java)..."
az webapp config appsettings set \
  --name "${WEBAPP_JAVA_NAME}" \
  --resource-group "${RESOURCE_GROUP_NAME}" \
  --settings \
    APPLICATIONINSIGHTS_CONNECTION_STRING="${APPINSIGHTS_CONNECTION_STRING}" \
    ApplicationInsightsAgent_EXTENSION_VERSION="~3" \
    XDT_MicrosoftApplicationInsights_Mode="Recommended" \
    XDT_MicrosoftApplicationInsights_PreemptSdk="1" \
    SPRING_PROFILES_ACTIVE="autonomus" \
    SPRING_DATASOURCE_URL="${ORACLE_JDBC_URL}" \
    SPRING_DATASOURCE_USERNAME="${ORACLE_USER}" \
    SPRING_DATASOURCE_PASSWORD="${ORACLE_PASSWORD}" \
    SPRING_RABBITMQ_HOST="${RABBIT_FQDN}" \
    SPRING_RABBITMQ_PORT="5672" \
    SPRING_RABBITMQ_USERNAME="admin" \
    SPRING_RABBITMQ_PASSWORD="admin" \
    SPRING_RABBITMQ_VIRTUAL_HOST="email" \
    WEBSITES_PORT="8080" \
  --output none

echo ">> Application Settings (.NET)..."
az webapp config appsettings set \
  --name "${WEBAPP_DOTNET_NAME}" \
  --resource-group "${RESOURCE_GROUP_NAME}" \
  --settings \
    APPLICATIONINSIGHTS_CONNECTION_STRING="${APPINSIGHTS_CONNECTION_STRING}" \
    ApplicationInsightsAgent_EXTENSION_VERSION="~3" \
    XDT_MicrosoftApplicationInsights_Mode="Recommended" \
    XDT_MicrosoftApplicationInsights_PreemptSdk="1" \
    "ConnectionStrings__OracleDb=${DOTNET_ORACLE_CONN}" \
    "Jwt__Key=${JWT_KEY}" \
    "Jwt__Issuer=SolarMetrics" \
    "Jwt__Audience=SolarMetrics" \
    ASPNETCORE_ENVIRONMENT="Staging" \
    WEBSITES_PORT="8080" \
    WEBSITES_CONTAINER_START_TIME_LIMIT="1800" \
    ASPNETCORE_FORWARDEDHEADERS_ENABLED="true" \
    SCM_DO_BUILD_DURING_DEPLOYMENT="false" \
    WEBSITE_HEALTHCHECK_PATH="/health/live" \
    MongoDb__Enabled=true \
    "MongoDb__ConnectionString=${MONGO_CONN}" \
    MongoDb__DatabaseName="${MONGO_DATABASE_NAME}" \
    MongoDb__ChatbotInteractionsCollection="${MONGO_COLLECTION}" \
  --output none

# API em Staging: /auth/token fica ativo (em Production a API devolve 404 e o MVC não obtém JWT).
echo ">> Application Settings (SolarMetrics.Web / MVC)..."
az webapp config appsettings set \
  --name "${WEBAPP_WEB_NAME}" \
  --resource-group "${RESOURCE_GROUP_NAME}" \
  --settings \
    APPLICATIONINSIGHTS_CONNECTION_STRING="${APPINSIGHTS_CONNECTION_STRING}" \
    ApplicationInsightsAgent_EXTENSION_VERSION="~3" \
    XDT_MicrosoftApplicationInsights_Mode="Recommended" \
    XDT_MicrosoftApplicationInsights_PreemptSdk="1" \
    "Api__BaseUrl=${DOTNET_API_PUBLIC_URL}" \
    "ConnectionStrings__OracleDb=${DOTNET_ORACLE_CONN}" \
    "Jwt__Key=${JWT_KEY}" \
    "Jwt__Issuer=SolarMetrics" \
    "Jwt__Audience=SolarMetrics" \
    "Jwt__ExpirationMinutes=120" \
    ASPNETCORE_ENVIRONMENT="Production" \
    WEBSITES_PORT="8080" \
    WEBSITES_CONTAINER_START_TIME_LIMIT="1800" \
    ASPNETCORE_FORWARDEDHEADERS_ENABLED="true" \
    SCM_DO_BUILD_DURING_DEPLOYMENT="false" \
    WEBSITE_HEALTHCHECK_PATH="/Account/Login" \
    MongoDb__Enabled=true \
    "MongoDb__ConnectionString=${MONGO_CONN}" \
    MongoDb__DatabaseName="${MONGO_DATABASE_NAME}" \
    MongoDb__ChatbotInteractionsCollection="${MONGO_COLLECTION}" \
  --output none

az monitor app-insights component connect-webapp \
  --app "${APP_INSIGHTS_NAME}" \
  --web-app "${WEBAPP_JAVA_NAME}" \
  --resource-group "${RESOURCE_GROUP_NAME}" \
  --output none 2>/dev/null || true
az monitor app-insights component connect-webapp \
  --app "${APP_INSIGHTS_NAME}" \
  --web-app "${WEBAPP_DOTNET_NAME}" \
  --resource-group "${RESOURCE_GROUP_NAME}" \
  --output none 2>/dev/null || true
az monitor app-insights component connect-webapp \
  --app "${APP_INSIGHTS_NAME}" \
  --web-app "${WEBAPP_WEB_NAME}" \
  --resource-group "${RESOURCE_GROUP_NAME}" \
  --output none 2>/dev/null || true

# ---------------------------------------------------------------------------
# Ferramentas de build / rede
# ---------------------------------------------------------------------------
require_cmd() {
  if ! command -v "$1" &>/dev/null; then
    echo "ERRO: comando não encontrado: $1" >&2
    exit 1
  fi
}

# Git Bash (MSYS): Python primeiro — entradas com caminhos relativos POSIX; alguns ZIPs do PowerShell
# geram HTTP 400 no OneDeploy. Cloud Shell: zip nativo primeiro (rápido).
_pack_dir_to_zip_python() {
  local src_dir="$1"
  local out_zip="$2"
  local pyexe="$3"
  "${pyexe}" -c "
import zipfile, pathlib, sys
src = pathlib.Path(sys.argv[1]).resolve()
out = pathlib.Path(sys.argv[2])
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    for p in src.rglob('*'):
        if p.is_file():
            z.write(p, p.relative_to(src).as_posix())
" "${src_dir}" "${out_zip}"
}

# Ordem: (MSYS) Python | zip | PowerShell | Python — py por último fora de MSYS (evita stub da Store)
pack_dir_to_zip() {
  local src_dir="$1"
  local out_zip="$2"
  rm -f "${out_zip}"
  if [[ -n "${MSYSTEM:-}" ]]; then
    if command -v python3 &>/dev/null && python3 -c "exit(0)" &>/dev/null; then
      _pack_dir_to_zip_python "${src_dir}" "${out_zip}" python3 && return 0
    fi
    if command -v python &>/dev/null && python -c "exit(0)" &>/dev/null 2>&1; then
      _pack_dir_to_zip_python "${src_dir}" "${out_zip}" python && return 0
    fi
  fi
  if command -v zip &>/dev/null; then
    ( cd "${src_dir}" && zip -q -r "${out_zip}" . )
    return 0
  fi
  local PS=""
  command -v powershell.exe &>/dev/null && PS=powershell.exe
  [[ -z "${PS}" ]] && command -v pwsh &>/dev/null && PS=pwsh
  if [[ -n "${PS}" ]]; then
    local win_src win_out
    win_src=$(cd "${src_dir}" && pwd -W 2>/dev/null || cygpath -aw "${src_dir}" 2>/dev/null)
    win_out=$(cygpath -aw "${out_zip}" 2>/dev/null || echo "${out_zip}")
    [[ -n "${win_src}" ]] || { echo "ERRO: caminho Windows para compactação." >&2; exit 1; }
    "${PS}" -NoProfile -Command "Compress-Archive -Path '${win_src}\\*' -DestinationPath '${win_out}' -Force"
    return 0
  fi
  if command -v python3 &>/dev/null && python3 -c "exit(0)" &>/dev/null; then
    _pack_dir_to_zip_python "${src_dir}" "${out_zip}" python3
    return 0
  fi
  if command -v python &>/dev/null && python -c "exit(0)" &>/dev/null 2>&1; then
    _pack_dir_to_zip_python "${src_dir}" "${out_zip}" python
    return 0
  fi
  echo "ERRO: instale 'zip', use Azure Cloud Shell, ou instale Python/PowerShell para gerar o .zip de deploy." >&2
  exit 1
}

# OneDeploy (az webapp deploy) pode retornar HTTP 400 com certos ZIPs; Kudu /api/zipdeploy costuma aceitar o mesmo ficheiro.
kudu_zipdeploy_from_file() {
  local zipfile="$1"
  local webapp_name="$2"
  local ku kp scm_base
  ku=$(az webapp deployment list-publishing-profiles \
    --name "${webapp_name}" \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --query "[?contains(publishUrl, 'scm.azurewebsites.net')].userName | [0]" -o tsv 2>/dev/null)
  kp=$(az webapp deployment list-publishing-profiles \
    --name "${webapp_name}" \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --query "[?contains(publishUrl, 'scm.azurewebsites.net')].userPWD | [0]" -o tsv 2>/dev/null)
  if [[ -z "${ku}" || -z "${kp}" ]]; then
    echo "ERRO: credenciais Kudu não obtidas (publishing profile)." >&2
    return 1
  fi
  scm_base="https://${webapp_name}.scm.azurewebsites.net"
  echo ">> Kudu zipdeploy (fallback): POST ${scm_base}/api/zipdeploy"
  curl -fsS -X POST -u "${ku}:${kp}" \
    -H "Content-Type: application/octet-stream" \
    --data-binary "@${zipfile}" \
    "${scm_base}/api/zipdeploy?isAsync=false"
}

git_url_to_tarball() {
  local u="$1"
  local br="$2"
  u="${u%.git}"
  echo "${u}/archive/refs/heads/${br}.tar.gz"
}

download_github_sources() {
  local giturl="$1"
  local branch="$2"
  local dest_name="$3"
  local tgz="${WORK_DIR}/dl-${dest_name}.tar.gz"
  local url
  url=$(git_url_to_tarball "${giturl}" "${branch}")
  echo ">> Baixando tarball: ${url}"
  curl -fsSL "${url}" -o "${tgz}" || return 1
  tar -xzf "${tgz}" -C "${WORK_DIR}" || return 1
  local repo_base
  repo_base=$(basename "${giturl%.git}")
  local extracted="${WORK_DIR}/${repo_base}-${branch}"
  if [[ ! -d "${extracted}" ]]; then
    extracted=$(find "${WORK_DIR}" -maxdepth 1 -type d -name "${repo_base}-*" | head -1)
  fi
  [[ -d "${extracted}" ]] || { echo "ERRO: pasta extraída não encontrada (${repo_base}-${branch})." >&2; return 1; }
  rm -rf "${WORK_DIR}/${dest_name}"
  mv "${extracted}" "${WORK_DIR}/${dest_name}" || return 1
  return 0
}

echo ">> Verificando ferramentas: curl, tar, unzip, dotnet, (zip|powershell|python)..."
require_cmd curl
require_cmd tar
require_cmd unzip
require_cmd dotnet
if ! command -v zip &>/dev/null; then
  if ! command -v powershell.exe &>/dev/null && ! command -v pwsh &>/dev/null; then
    if ! { command -v python3 &>/dev/null && python3 -c "exit(0)" &>/dev/null; } && ! { command -v python &>/dev/null && python -c "exit(0)" &>/dev/null 2>&1; }; then
      echo "ERRO: é necessário 'zip' (Cloud Shell tem), PowerShell ou Python funcional para empacotar." >&2
      exit 1
    fi
  fi
fi

if [[ "${USE_GIT_CLONE}" == "1" ]]; then
  require_cmd git
fi

# ---------------------------------------------------------------------------
# Diretório de trabalho
# ---------------------------------------------------------------------------
if [[ -n "${DEPLOY_WORK_DIR}" ]]; then
  WORK_DIR="${DEPLOY_WORK_DIR}"
  mkdir -p "${WORK_DIR}"
else
  WORK_DIR=$(mktemp -d 2>/dev/null || echo "${SCRIPT_DIR}/.deploy-work-$$")
  mkdir -p "${WORK_DIR}"
  trap '[[ -z "${DEPLOY_WORK_DIR}" ]] && rm -rf "${WORK_DIR}"' EXIT
fi

echo ">> Diretório de trabalho: ${WORK_DIR}"

# ---------------------------------------------------------------------------
# Resolver wallet (.zip) — URL, caminho local ou padrão ao lado do script
# ---------------------------------------------------------------------------
WALLET_LOCAL_DEFAULT="${SCRIPT_DIR}/step-by-step-cloud/Wallet_TAD4HZ13PJ8XYHAW.zip"
resolve_wallet_path() {
  if [[ -n "${WALLET_URL}" ]]; then
    echo ">> Baixando wallet Oracle (WALLET_URL)..." >&2
    curl -fsSL "${WALLET_URL}" -o "${WORK_DIR}/oracle-wallet.zip"
    echo "${WORK_DIR}/oracle-wallet.zip"
    return 0
  fi
  if [[ -n "${WALLET_ZIP}" ]]; then
    if [[ "${WALLET_ZIP}" =~ ^https?:// ]]; then
      echo ">> Baixando wallet Oracle (WALLET_ZIP é URL)..." >&2
      curl -fsSL "${WALLET_ZIP}" -o "${WORK_DIR}/oracle-wallet.zip"
      echo "${WORK_DIR}/oracle-wallet.zip"
      return 0
    fi
    if [[ -f "${WALLET_ZIP}" ]]; then
      echo "${WALLET_ZIP}"
      return 0
    fi
    echo "ERRO: WALLET_ZIP não é um arquivo válido: ${WALLET_ZIP}" >&2
    exit 1
  fi
  if [[ -f "${WALLET_LOCAL_DEFAULT}" ]]; then
    echo ">> Usando wallet local (repositório DevOps): ${WALLET_LOCAL_DEFAULT}" >&2
    echo "${WALLET_LOCAL_DEFAULT}"
    return 0
  fi
  echo "ERRO: defina WALLET_URL com o HTTPS do wallet .zip (recomendado na nuvem), ou coloque o zip em:" >&2
  echo "      ${WALLET_LOCAL_DEFAULT}" >&2
  exit 1
}

REAL_WALLET_ZIP="$(resolve_wallet_path)"
echo ">> Wallet resolvido para extração: ${REAL_WALLET_ZIP}"

rm -rf "${WORK_DIR}/wallet-unpack" "${WORK_DIR}/wallet-flat"
mkdir -p "${WORK_DIR}/wallet-unpack"
unzip -q -o "${REAL_WALLET_ZIP}" -d "${WORK_DIR}/wallet-unpack"

TNS_FILE=$(find "${WORK_DIR}/wallet-unpack" -name 'tnsnames.ora' -type f | head -1)
if [[ -z "${TNS_FILE}" ]]; then
  echo "ERRO: tnsnames.ora não encontrado no wallet." >&2
  exit 1
fi
WALLET_SOURCE_DIR=$(dirname "${TNS_FILE}")
mkdir -p "${WORK_DIR}/wallet-flat"
cp -r "${WALLET_SOURCE_DIR}"/* "${WORK_DIR}/wallet-flat/"

# ---------------------------------------------------------------------------
# .NET — fonte via tarball ou git
# ---------------------------------------------------------------------------
echo ">> [1/3] Obter código + publish API .NET (${GIT_URL_DOTNET})..."
DOTNET_CLONE="${WORK_DIR}/SolarMetrics-Dotnet"
rm -rf "${DOTNET_CLONE}"

if [[ "${USE_GIT_CLONE}" == "1" ]]; then
  git clone --depth 1 --branch "${GIT_BRANCH}" "${GIT_URL_DOTNET}" "${DOTNET_CLONE}"
else
  download_github_sources "${GIT_URL_DOTNET}" "${GIT_BRANCH}" "SolarMetrics-Dotnet" || {
    echo "ERRO: não foi possível baixar o código .NET (tarball)." >&2
    exit 1
  }
fi

DOTNET_PUB="${WORK_DIR}/dotnet-publish"
rm -rf "${DOTNET_PUB}"
dotnet publish "${DOTNET_CLONE}/SolarMetrics.API/SolarMetrics.API.csproj" -c Release -o "${DOTNET_PUB}" /p:PublishReadyToRun=true

mkdir -p "${DOTNET_PUB}/wallet"
cp -r "${WORK_DIR}/wallet-flat/"* "${DOTNET_PUB}/wallet/"

DOTNET_ZIP="${WORK_DIR}/dotnet-deploy.zip"
pack_dir_to_zip "${DOTNET_PUB}" "${DOTNET_ZIP}"

DOTNET_DEPLOY_SRC="${DOTNET_ZIP}"
if command -v cygpath &>/dev/null; then
  DOTNET_DEPLOY_SRC="$(cygpath -w "${DOTNET_ZIP}" 2>/dev/null || echo "${DOTNET_ZIP}")"
fi

echo ">> Deploy .NET → ${WEBAPP_DOTNET_NAME} (--type zip; Git Bash: ZIP preferencialmente via Python)..."
set +e
az webapp deploy \
  --resource-group "${RESOURCE_GROUP_NAME}" \
  --name "${WEBAPP_DOTNET_NAME}" \
  --src-path "${DOTNET_DEPLOY_SRC}" \
  --type zip \
  --timeout 1800000
DOTNET_DEPLOY_EC=$?
set -e
if [[ "${DOTNET_DEPLOY_EC}" -ne 0 ]]; then
  echo ">> az webapp deploy falhou (exit ${DOTNET_DEPLOY_EC}); tentando Kudu /api/zipdeploy..."
  kudu_zipdeploy_from_file "${DOTNET_ZIP}" "${WEBAPP_DOTNET_NAME}" || exit 1
fi

# ---------------------------------------------------------------------------
# SolarMetrics.Web (MVC) — mesmo clone, segundo publish
# ---------------------------------------------------------------------------
echo ">> [2/3] Publish + deploy SolarMetrics.Web → ${WEBAPP_WEB_NAME}..."
WEB_PUB="${WORK_DIR}/dotnet-web-publish"
rm -rf "${WEB_PUB}"
dotnet publish "${DOTNET_CLONE}/SolarMetrics.Web/SolarMetrics.Web.csproj" -c Release -o "${WEB_PUB}" /p:PublishReadyToRun=true

mkdir -p "${WEB_PUB}/wallet"
cp -r "${WORK_DIR}/wallet-flat/"* "${WEB_PUB}/wallet/"

WEB_ZIP="${WORK_DIR}/dotnet-web-deploy.zip"
pack_dir_to_zip "${WEB_PUB}" "${WEB_ZIP}"

WEB_DEPLOY_SRC="${WEB_ZIP}"
if command -v cygpath &>/dev/null; then
  WEB_DEPLOY_SRC="$(cygpath -w "${WEB_ZIP}" 2>/dev/null || echo "${WEB_ZIP}")"
fi

set +e
az webapp deploy \
  --resource-group "${RESOURCE_GROUP_NAME}" \
  --name "${WEBAPP_WEB_NAME}" \
  --src-path "${WEB_DEPLOY_SRC}" \
  --type zip \
  --timeout 1800000
WEB_DEPLOY_EC=$?
set -e
if [[ "${WEB_DEPLOY_EC}" -ne 0 ]]; then
  echo ">> az webapp deploy (Web) falhou (exit ${WEB_DEPLOY_EC}); tentando Kudu /api/zipdeploy..."
  kudu_zipdeploy_from_file "${WEB_ZIP}" "${WEBAPP_WEB_NAME}" || exit 1
fi

# ---------------------------------------------------------------------------
# Java — melhor esforço
# ---------------------------------------------------------------------------
echo ">> [3/3] Obter código + Maven + deploy Java (${GIT_URL_JAVA})..."
deploy_java_best_effort() {
  set +e
  local JCLONE="${WORK_DIR}/SolarMetrics-JavaAdvanced"
  rm -rf "${JCLONE}"
  if [[ "${USE_GIT_CLONE}" == "1" ]]; then
    git clone --depth 1 --branch "${GIT_BRANCH}" "${GIT_URL_JAVA}" "${JCLONE}" || { echo "AVISO: git clone Java falhou."; set -e; return 0; }
  else
    if ! download_github_sources "${GIT_URL_JAVA}" "${GIT_BRANCH}" "SolarMetrics-JavaAdvanced"; then
      echo "AVISO: download tarball Java falhou — deploy Java ignorado."
      set -e
      return 0
    fi
  fi
  if ! command -v mvn &>/dev/null; then
    echo "AVISO: mvn não encontrado — deploy Java ignorado."
    set -e
    return 0
  fi
  ( cd "${JCLONE}" && mvn -q -DskipTests package )
  local MVN_EC=$?
  if [[ "${MVN_EC}" -ne 0 ]]; then
    echo "AVISO: mvn falhou (${MVN_EC}) — deploy Java ignorado."
    set -e
    return 0
  fi
  local JAR
  JAR=$(find "${JCLONE}/target" -maxdepth 1 -name '*.jar' ! -name '*-sources.jar' ! -name '*-javadoc.jar' | head -1)
  if [[ -z "${JAR}" || ! -f "${JAR}" ]]; then
    echo "AVISO: JAR não encontrado — deploy Java ignorado."
    set -e
    return 0
  fi
  local JSTAGE="${WORK_DIR}/java-stage"
  rm -rf "${JSTAGE}"
  mkdir -p "${JSTAGE}/wallet"
  cp "${JAR}" "${JSTAGE}/app.jar"
  cp -r "${WORK_DIR}/wallet-flat/"* "${JSTAGE}/wallet/"
  local JZIP="${WORK_DIR}/java-deploy.zip"
  pack_dir_to_zip "${JSTAGE}" "${JZIP}"
  az webapp deploy \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --name "${WEBAPP_JAVA_NAME}" \
    --src-path "${JZIP}" \
    --type zip \
    --timeout 1800000 \
    && echo ">> Deploy Java OK." \
    || echo "AVISO: az webapp deploy (Java) falhou."
  set -e
}
deploy_java_best_effort

for APP_NAME in "${WEBAPP_JAVA_NAME}" "${WEBAPP_DOTNET_NAME}" "${WEBAPP_WEB_NAME}"; do
  echo ">> Reiniciando ${APP_NAME}..."
  az webapp restart --name "${APP_NAME}" --resource-group "${RESOURCE_GROUP_NAME}" --output none
done

echo ""
echo "============================================================================"
echo " Concluído."
echo " Java:      https://${WEBAPP_JAVA_NAME}.azurewebsites.net"
echo " API .NET:  https://${WEBAPP_DOTNET_NAME}.azurewebsites.net"
echo " Web MVC:   https://${WEBAPP_WEB_NAME}.azurewebsites.net"
echo " Rabbit:    amqp://${RABBIT_FQDN}:5672"
echo " MongoDB:   mongodb://${MONGO_FQDN}:27017 (db=${MONGO_DATABASE_NAME})"
echo "============================================================================"
