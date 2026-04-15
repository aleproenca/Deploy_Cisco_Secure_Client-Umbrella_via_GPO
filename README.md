# Deploy Automatizado Cisco Secure Client + Umbrella via GPO

Script em PowerShell para instalação padronizada, silenciosa e idempotente do **Cisco Secure Client** com o módulo **Umbrella Roaming Security**.

O script remove instalações antigas, instala a versão desejada, força o `OrgInfo.json` correto e registra a instalação no Registro do Windows.

## Objetivo

Garantir que todos os computadores da empresa sejam instalados com:
- Cisco Secure Client (full package)
- Módulo Umbrella configurado com a Organization ID correta
- Configuração consistente em escala via **Active Directory Group Policy (GPO)**

## Como funciona

1. Verifica se já existe instalação válida (flag no Registro + `OrgInfo.json` correto).
2. Caso não exista ou esteja incorreta:
   - Remove qualquer versão anterior do Cisco Secure Client.
   - Instala silenciosamente o pacote `csc-deploy-full-Default-CSA.exe`.
   - Limpa a pasta de dados do Umbrella.
   - Cria e copia o arquivo `OrgInfo.json` com a `organizationId` da empresa.
   - Reinicia os serviços necessários.
3. Registra a instalação no Registro (`HKLM:\Software\CiscoSecureClient`).

O script é **idempotente** — pode ser executado várias vezes sem duplicar instalações.

## Estrutura do Projeto
