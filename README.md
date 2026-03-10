# OVH Scripts

Scripts shell para configuração de rede em instâncias OVH — Additional IPs, Failover e automação de rede no Debian 12 e Ubuntu 22.04+.

---

## Scripts disponíveis

### `ovh_add_failover_ip.sh`

Adiciona múltiplos **Additional IPs (Failover)** seguindo exatamente o padrão da [documentação oficial OVH](https://help.ovhcloud.com/csm/pt-public-cloud-network-configure-additional-ip?id=kb_article_view&sysparm_article=KB0050256).

**O script executa as 3 etapas oficiais:**

1. Desativa a configuração automática do cloud-init (`99-disable-network-config.cfg`)
2. Adiciona os IPs no arquivo Netplan (`/etc/netplan/50-cloud-init.yaml`) com máscara `/32`
3. Testa com `netplan try` e aplica com `netplan apply`

**Funcionalidades:**
- Detecta automaticamente a interface de rede e o arquivo Netplan ativo
- Valida o formato dos IPs informados
- Evita duplicatas — pula IPs já configurados
- Faz backup automático do arquivo Netplan antes de qualquer alteração
- Restaura o backup automaticamente se `netplan try` falhar
- Interativo: confirma cada etapa antes de executar

---

## Requisitos

- Debian 12 ou Ubuntu 22.04 / 24.04
- Additional IPs (Failover) adquiridos no painel OVHcloud
- Acesso root (`sudo`)

---

## Como usar

```bash
curl -fsSL https://raw.githubusercontent.com/pinguimpi/ovh-scripts/main/ovh_add_failover_ip.sh -o /tmp/ovh_add_failover_ip.sh && sudo bash /tmp/ovh_add_failover_ip.sh
```

---

## Exemplo de execução

```
============================================
  OVH — Adicionar Additional IPs
  Netplan | Debian 12 / Ubuntu 22.04+
============================================

  Interface detectada : ens3
  Arquivo Netplan     : /etc/netplan/50-cloud-init.yaml

[ ETAPA 1 ] Desativar configuração automática da rede (cloud-init)
  [OK] Arquivo criado: /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg

[ ETAPA 2 ] Modificar o arquivo de configuração Netplan

Digite os Additional IPs um por linha.
  Apenas o IP (ex: 198.51.100.10). Enter em branco para finalizar.

  Additional IP (ou Enter para finalizar): 203.0.113.10
  [OK] 203.0.113.10 adicionado.
  Additional IP (ou Enter para finalizar): 203.0.113.11
  [OK] 203.0.113.11 adicionado.
  Additional IP (ou Enter para finalizar):

============================================
  Resumo das alterações
============================================

  + 203.0.113.10/32 → /etc/netplan/50-cloud-init.yaml
  + 203.0.113.11/32 → /etc/netplan/50-cloud-init.yaml

Confirma a aplicação? (s/n): s
[BACKUP] Salvo em: /etc/netplan/50-cloud-init.yaml.bak_20260310_143000

[ ETAPA 3 ] Testar e aplicar configuração
  Executando netplan try (timeout 30s)...
  [OK] Configuração validada.

Aplicar definitivamente com 'netplan apply'? (s/n): s

============================================
  IPs aplicados com sucesso!
============================================

  IPs ativos na interface ens3:
    10.0.0.1/24
    203.0.113.10/32
    203.0.113.11/32
```

---

## Diagnóstico

Se o IP não responder após a aplicação, a própria OVH recomenda reiniciar a instância em **modo rescue** e testar com:

```bash
ifconfig ens3:0 ADDITIONAL_IP netmask 255.255.255.255 broadcast ADDITIONAL_IP up
```

Se o IP responder em modo rescue, o problema é de configuração. Se não responder, abra um ticket no painel OVHcloud.

---

## Licença

[GPL-3.0](LICENSE)
