# OVH Scripts

Scripts shell para configuração de rede em VPS OVH — Additional IPs, Failover e automação de rede no Ubuntu LTS.

---

## Scripts disponíveis

### `ovh_add_failover_ip.sh`

Adiciona múltiplos **Additional IPs (Failover)** em um VPS OVH com Ubuntu LTS, seguindo exatamente o padrão da [documentação oficial OVH](https://help.ovhcloud.com/csm/pt-vps-network-ip?id=kb_article_view&sysparm_article=KB0047718).

**O script executa as 3 etapas oficiais:**

1. Desativa a configuração automática do cloud-init (`99-disable-network-config.cfg`)
2. Adiciona os IPs em `/etc/network/interfaces.d/50-cloud-init` com `netmask 255.255.255.255`
3. Reinicia o serviço de rede com `systemctl restart networking`

**Funcionalidades:**
- Detecta automaticamente a interface de rede principal
- Calcula o próximo ID de alias disponível (`:0`, `:1`, `:2`...)
- Valida o formato dos IPs informados
- Evita duplicatas — pula IPs já configurados
- Faz backup automático do arquivo de interfaces antes de qualquer alteração
- Interativo: confirma cada etapa antes de executar

---

## Requisitos

- Ubuntu LTS 20.04 / 22.04 / 24.04
- VPS OVH com Additional IPs (Failover) adquiridos no painel OVH
- Acesso root (`sudo`)

---

## Como usar

### Execução direta (um único comando)

```bash
sudo bash <(curl -fsSL https://raw.githubusercontent.com/pinguimpi/ovh-scripts/main/ovh_add_failover_ip.sh)
```

### Ou baixando o script primeiro

```bash
curl -fsSL https://raw.githubusercontent.com/pinguimpi/ovh-scripts/main/ovh_add_failover_ip.sh -o ovh_add_failover_ip.sh
chmod +x ovh_add_failover_ip.sh
sudo bash ovh_add_failover_ip.sh
```

---

## Exemplo de uso

```
============================================
  OVH VPS — Adicionar Additional IPs
  Método: interfaces.d (padrão OVH)
============================================

  Interface detectada : eth0
  Arquivo de rede     : /etc/network/interfaces.d/50-cloud-init

[ ETAPA 1 ] Desativar configuração automática da rede (cloud-init)
  [OK] Arquivo criado: /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg

[ ETAPA 2 ] Verificando aliases já configurados
  Nenhum alias encontrado. Iniciando do ID: 0

Digite os Additional IPs um por linha.
  Apenas o IP (ex: 198.51.100.10). Enter em branco para finalizar.

  Additional IP (ou Enter para finalizar): 203.0.113.10
  [OK] 203.0.113.10 → eth0:0
  Additional IP (ou Enter para finalizar): 203.0.113.11
  [OK] 203.0.113.11 → eth0:1
  Additional IP (ou Enter para finalizar):

============================================
  Resumo das alterações
============================================

  + eth0:0  →  address 203.0.113.10  netmask 255.255.255.255
  + eth0:1  →  address 203.0.113.11  netmask 255.255.255.255

Confirma a aplicação? (s/n): s
```

---

## Licença

[GPL-3.0](LICENSE)
