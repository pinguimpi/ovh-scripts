#!/bin/bash
# ============================================================
#  OVH — Adicionar Additional IPs (Failover)
#  Método: Netplan (/etc/netplan/50-cloud-init.yaml)
#  Compatível: Debian 12, Ubuntu 22.04+
#  Documentação: https://help.ovhcloud.com/csm/pt-public-cloud-network-configure-additional-ip?id=kb_article_view&sysparm_article=KB0050256
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Root check ───────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}[ERRO]${NC} Execute como root: sudo bash $0"
  exit 1
fi

# ── Netplan check ────────────────────────────────────────────
if ! command -v netplan &>/dev/null; then
  echo -e "${RED}[ERRO]${NC} Netplan não encontrado. Este script requer Debian 12 ou Ubuntu 22.04+."
  exit 1
fi

CLOUD_CFG="/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg"
NETPLAN_DIR="/etc/netplan"

# ── Detectar interface principal ─────────────────────────────
INTERFACE=$(ip route | awk '/default/ {print $5; exit}')
if [[ -z "$INTERFACE" ]]; then
  echo -e "${RED}[ERRO]${NC} Não foi possível detectar a interface de rede principal."
  exit 1
fi

# ── Detectar arquivo netplan ─────────────────────────────────
NETPLAN_FILE=$(ls "$NETPLAN_DIR"/*.yaml 2>/dev/null | head -1)
if [[ -z "$NETPLAN_FILE" ]]; then
  echo -e "${RED}[ERRO]${NC} Nenhum arquivo .yaml encontrado em $NETPLAN_DIR"
  exit 1
fi

# ── Cabeçalho ────────────────────────────────────────────────
clear
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  OVH — Adicionar Additional IPs           ${NC}"
echo -e "${CYAN}  Netplan | Debian 12 / Ubuntu 22.04+      ${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
echo -e "  Interface detectada : ${GREEN}${INTERFACE}${NC}"
echo -e "  Arquivo Netplan     : ${GREEN}${NETPLAN_FILE}${NC}"
echo ""

# ── ETAPA 1: Desativar cloud-init ────────────────────────────
echo -e "${CYAN}[ ETAPA 1 ]${NC} Desativar configuração automática da rede (cloud-init)"
echo ""

if [[ -f "$CLOUD_CFG" ]]; then
  echo -e "  ${YELLOW}[JÁ EXISTE]${NC} $CLOUD_CFG — nenhuma alteração necessária."
else
  echo "network: {config: disabled}" > "$CLOUD_CFG"
  echo -e "  ${GREEN}[OK]${NC} Arquivo criado: $CLOUD_CFG"
fi
echo ""

# ── ETAPA 2: Coletar IPs ─────────────────────────────────────
echo -e "${CYAN}[ ETAPA 2 ]${NC} Modificar o arquivo de configuração Netplan"
echo ""
echo -e "${CYAN}Digite os Additional IPs um por linha.${NC}"
echo -e "  Apenas o IP (ex: 198.51.100.10). Enter em branco para finalizar."
echo ""

IPS=()
while true; do
  read -rp "  Additional IP (ou Enter para finalizar): " IP_INPUT
  [[ -z "$IP_INPUT" ]] && break

  # Validação básica IPv4
  if [[ ! "$IP_INPUT" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo -e "  ${RED}[INVÁLIDO]${NC} Use apenas o IP sem máscara (ex: 198.51.100.10)"
    continue
  fi

  # Duplicata na sessão
  if printf '%s\n' "${IPS[@]}" | grep -qx "$IP_INPUT"; then
    echo -e "  ${YELLOW}[AVISO]${NC} $IP_INPUT já adicionado nesta sessão."
    continue
  fi

  # Já existe no arquivo
  if grep -q "${IP_INPUT}/32" "$NETPLAN_FILE" 2>/dev/null; then
    echo -e "  ${YELLOW}[AVISO]${NC} $IP_INPUT já está configurado no arquivo — ignorado."
    continue
  fi

  IPS+=("$IP_INPUT")
  echo -e "  ${GREEN}[OK]${NC} $IP_INPUT adicionado."
done

# ── Sem IPs ──────────────────────────────────────────────────
if [[ ${#IPS[@]} -eq 0 ]]; then
  echo ""
  echo -e "${YELLOW}Nenhum IP informado. Encerrando sem alterações.${NC}"
  exit 0
fi

# ── Resumo ───────────────────────────────────────────────────
echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  Resumo das alterações                    ${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
for IP in "${IPS[@]}"; do
  echo -e "  ${GREEN}+${NC} ${IP}/32 → ${NETPLAN_FILE}"
done
echo ""

read -rp "$(echo -e "${YELLOW}Confirma a aplicação? (s/n): ${NC}")" CONFIRM
if [[ "$CONFIRM" != "s" && "$CONFIRM" != "S" ]]; then
  echo -e "${YELLOW}Operação cancelada. Nenhuma alteração foi feita.${NC}"
  exit 0
fi

# ── Backup ───────────────────────────────────────────────────
BACKUP="${NETPLAN_FILE}.bak_$(date +%Y%m%d_%H%M%S)"
cp "$NETPLAN_FILE" "$BACKUP"
echo -e "\n${YELLOW}[BACKUP]${NC} Salvo em: $BACKUP"

# ── Verificar se já existe bloco 'addresses:' na interface ───
HAS_ADDRESSES=$(grep -c "^\s*addresses:" "$NETPLAN_FILE" || true)

if [[ "$HAS_ADDRESSES" -gt 0 ]]; then
  # Adicionar IPs na linha após 'addresses:'
  for IP in "${IPS[@]}"; do
    # Detectar indentação do bloco addresses
    INDENT=$(grep -m1 "addresses:" "$NETPLAN_FILE" | sed 's/addresses:.*//' | cat -A | sed 's/\$//;s/\^I/  /g')
    # Inserir após a linha addresses:
    sed -i "/^\s*addresses:/a\\            - ${IP}/32" "$NETPLAN_FILE"
    echo -e "  ${GREEN}[OK]${NC} ${IP}/32 adicionado ao bloco addresses"
  done
else
  # Não existe bloco addresses — adicionar antes do fim do bloco da interface
  ADDRESSES_BLOCK="            addresses:"
  for IP in "${IPS[@]}"; do
    ADDRESSES_BLOCK+="\n            - ${IP}/32"
  done
  # Inserir após set-name ou dhcp4 line da interface
  sed -i "/set-name: ${INTERFACE}/a\\${ADDRESSES_BLOCK}" "$NETPLAN_FILE"
  echo -e "  ${GREEN}[OK]${NC} Bloco addresses criado com os IPs"
fi

echo ""

# ── ETAPA 3: Testar e aplicar ────────────────────────────────
echo -e "${CYAN}[ ETAPA 3 ]${NC} Testar e aplicar configuração"
echo ""

echo -e "  Executando ${CYAN}netplan try${NC} (timeout 30s)..."
echo ""

if netplan try --timeout 30; then
  echo ""
  echo -e "  ${GREEN}[OK]${NC} Configuração validada."
  echo ""
  read -rp "$(echo -e "${YELLOW}Aplicar definitivamente com 'netplan apply'? (s/n): ${NC}")" APPLY
  if [[ "$APPLY" == "s" || "$APPLY" == "S" ]]; then
    netplan apply
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  IPs aplicados com sucesso!               ${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo -e "  IPs ativos na interface ${INTERFACE}:"
    ip addr show "$INTERFACE" | grep "inet " | awk '{print "    " $2}'
  else
    echo -e "${YELLOW}Configuração salva mas não aplicada definitivamente.${NC}"
    echo -e "  Execute manualmente: ${CYAN}sudo netplan apply${NC}"
  fi
else
  echo ""
  echo -e "${RED}[ERRO]${NC} netplan try falhou. Restaurando backup..."
  cp "$BACKUP" "$NETPLAN_FILE"
  echo -e "${YELLOW}[RESTAURADO]${NC} Arquivo original restaurado de: $BACKUP"
  echo -e "Verifique o arquivo manualmente: ${CYAN}sudo nano $NETPLAN_FILE${NC}"
  exit 1
fi

echo ""
echo -e "${CYAN}Para verificar os IPs ativos:${NC}  ip addr show ${INTERFACE}"
echo ""
