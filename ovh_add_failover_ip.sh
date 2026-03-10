#!/bin/bash
# ============================================================
#  OVH VPS — Adicionar Additional IPs (Failover)
#  Método: /etc/network/interfaces.d/50-cloud-init
#  Padrão exato da documentação oficial OVH
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}[ERRO]${NC} Execute como root: sudo bash $0"
  exit 1
fi

INTERFACES_FILE="/etc/network/interfaces.d/50-cloud-init"
CLOUD_CFG="/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg"

INTERFACE=$(ip route | awk '/default/ {print $5; exit}')
if [[ -z "$INTERFACE" ]]; then
  echo -e "${RED}[ERRO]${NC} Não foi possível detectar a interface de rede principal."
  exit 1
fi

clear
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  OVH VPS — Adicionar Additional IPs       ${NC}"
echo -e "${CYAN}  Método: interfaces.d (padrão OVH)        ${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
echo -e "  Interface detectada : ${GREEN}${INTERFACE}${NC}"
echo -e "  Arquivo de rede     : ${GREEN}${INTERFACES_FILE}${NC}"
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

# ── ETAPA 2: Descobrir próximo ID de alias ───────────────────
echo -e "${CYAN}[ ETAPA 2 ]${NC} Verificando aliases já configurados"
echo ""

LAST_ID=-1
if [[ -f "$INTERFACES_FILE" ]]; then
  while IFS= read -r line; do
    if [[ "$line" =~ auto\ ${INTERFACE}:([0-9]+) ]]; then
      ID="${BASH_REMATCH[1]}"
      (( ID > LAST_ID )) && LAST_ID=$ID
    fi
  done < "$INTERFACES_FILE"
fi

NEXT_ID=$(( LAST_ID + 1 ))

if [[ $LAST_ID -ge 0 ]]; then
  echo -e "  Aliases existentes encontrados. Próximo ID: ${GREEN}${NEXT_ID}${NC}"
else
  echo -e "  Nenhum alias encontrado. Iniciando do ID: ${GREEN}0${NC}"
fi
echo ""

# ── Coletar IPs ──────────────────────────────────────────────
echo -e "${CYAN}Digite os Additional IPs um por linha.${NC}"
echo -e "  Apenas o IP (ex: 198.51.100.10). Enter em branco para finalizar."
echo ""

IPS=()
CURRENT_ID=$NEXT_ID

while true; do
  read -rp "  Additional IP (ou Enter para finalizar): " IP_INPUT
  [[ -z "$IP_INPUT" ]] && break

  if [[ ! "$IP_INPUT" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo -e "  ${RED}[INVÁLIDO]${NC} Use apenas o IP (ex: 198.51.100.10)"
    continue
  fi

  if printf '%s\n' "${IPS[@]}" | grep -qx "$IP_INPUT"; then
    echo -e "  ${YELLOW}[AVISO]${NC} $IP_INPUT já adicionado nesta sessão."
    continue
  fi

  if [[ -f "$INTERFACES_FILE" ]] && grep -q "address $IP_INPUT" "$INTERFACES_FILE"; then
    echo -e "  ${YELLOW}[AVISO]${NC} $IP_INPUT já está configurado no arquivo — ignorado."
    continue
  fi

  IPS+=("$IP_INPUT")
  echo -e "  ${GREEN}[OK]${NC} $IP_INPUT → ${INTERFACE}:${CURRENT_ID}"
  CURRENT_ID=$(( CURRENT_ID + 1 ))
done

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

ID_PREVIEW=$NEXT_ID
for IP in "${IPS[@]}"; do
  echo -e "  ${GREEN}+${NC} ${INTERFACE}:${ID_PREVIEW}  →  address ${IP}  netmask 255.255.255.255"
  ID_PREVIEW=$(( ID_PREVIEW + 1 ))
done

echo ""
read -rp "$(echo -e "${YELLOW}Confirma a aplicação? (s/n): ${NC}")" CONFIRM
if [[ "$CONFIRM" != "s" && "$CONFIRM" != "S" ]]; then
  echo -e "${YELLOW}Operação cancelada. Nenhuma alteração foi feita.${NC}"
  exit 0
fi

# ── Backup ───────────────────────────────────────────────────
if [[ -f "$INTERFACES_FILE" ]]; then
  BACKUP="${INTERFACES_FILE}.bak_$(date +%Y%m%d_%H%M%S)"
  cp "$INTERFACES_FILE" "$BACKUP"
  echo -e "\n${YELLOW}[BACKUP]${NC} Salvo em: $BACKUP"
fi

# ── Escrever no arquivo ──────────────────────────────────────
echo ""
echo -e "${CYAN}[ ETAPA 2 ]${NC} Escrevendo IPs em ${INTERFACES_FILE}"
echo ""

ID_WRITE=$NEXT_ID
for IP in "${IPS[@]}"; do
  printf "\nauto %s:%d\niface %s:%d inet static\naddress %s\nnetmask 255.255.255.255\n" \
    "$INTERFACE" "$ID_WRITE" "$INTERFACE" "$ID_WRITE" "$IP" >> "$INTERFACES_FILE"
  echo -e "  ${GREEN}[OK]${NC} ${INTERFACE}:${ID_WRITE} → ${IP}"
  ID_WRITE=$(( ID_WRITE + 1 ))
done

# ── ETAPA 3: Reiniciar networking ────────────────────────────
echo ""
echo -e "${CYAN}[ ETAPA 3 ]${NC} Reiniciar a interface de rede"
echo ""
read -rp "$(echo -e "${YELLOW}Reiniciar o networking agora? (sudo systemctl restart networking) (s/n): ${NC}")" RESTART

if [[ "$RESTART" == "s" || "$RESTART" == "S" ]]; then
  systemctl restart networking
  echo ""
  echo -e "${GREEN}============================================${NC}"
  echo -e "${GREEN}  IPs aplicados com sucesso!               ${NC}"
  echo -e "${GREEN}============================================${NC}"
  echo ""
  echo -e "  IPs ativos na interface ${INTERFACE}:"
  ip addr show "$INTERFACE" | grep "inet " | awk '{print "    " $2}'
else
  echo ""
  echo -e "${YELLOW}Networking NÃO reiniciado. Para aplicar manualmente:${NC}"
  echo -e "  ${CYAN}sudo systemctl restart networking${NC}"
fi

echo ""
echo -e "${CYAN}Para verificar os IPs ativos:${NC}  ip addr show ${INTERFACE}"
echo ""
