Aqui está um README.md completo, profissional e bem organizado, pronto para você colocar no GitHub.Copie e cole diretamente no seu repositório (recomendo usar o nome do repositório como Cisco-Secure-Client-Umbrella-GPO-Deployment ou similar).markdown

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

Cisco-Secure-Client-Umbrella-GPO/
├── Install-CiscoSecureClient.ps1     ← Script principal
├── csc-deploy-full-Default-CSA.exe   ← Instalador (não versionar no Git)
├── README.md
└── (opcional) log de execução

## Pré-requisitos

- Active Directory com Group Policy Management
- Computadores Windows 10/11 (64-bit)
- Permissões de Administrador (o script deve rodar como **System**)
- Pasta de rede compartilhada com leitura para os computadores (`\\servidor\NETLOGON` ou DFS)
- O arquivo `csc-deploy-full-Default-CSA.exe` baixado do Cisco Umbrella ou Cisco Software Portal

## Configuração via GPO (Recomendado)

### 1. Copiar arquivos (GPO Preferences → Files)

Crie um **File Preference**:

- **Action**: Update
- Source: `\\SEU-SERVIDOR\Share\Cisco\csc-deploy-full-Default-CSA.exe`
- Destination: `C:\Temp\csc-deploy-full-Default-CSA.exe`
- (Opcional) Copie também o `.ps1` para `C:\Temp\Install-CiscoSecureClient.ps1`

### 2. Executar o script (GPO Preferences → Immediate Task)

Crie uma **Immediate Task** (Computer Configuration):

- **Action**: Update
- **Name**: Install Cisco Secure Client + Umbrella
- **Program/Script**: `powershell.exe`
- **Arguments**:

  -NoProfile -ExecutionPolicy Bypass -File "C:\Temp\Install-CiscoSecureClient.ps1"

- **Run as**: **System**
- Desmarque a opção "Run in logged-on user's security context" (deve rodar como SYSTEM)
- (Opcional) Adicione **Item-level targeting** por OU ou grupo de computadores

**Ordem importante**: O item de cópia de arquivos deve vir **antes** da tarefa de execução.

### Alternativa Avançada

- Rodar como **Computer Startup Script** (em vez de Immediate Task) → executa toda vez que o computador liga.
- Usar **Scheduled Task** com delay de 5–10 minutos após o boot.

## Personalização do Script

Antes de usar, edite as seguintes variáveis no início do script:

```powershell
$expected = [PSCustomObject]@{
  organizationId = "SEU_ORG_ID_AQUI"   # ← Mude para o ID real da sua organização no Umbrella
  region         = "global"
  userId         = "000000"
}

powershell

$InstallerPath = "C:\Temp\csc-deploy-full-Default-CSA.exe"

Você pode transformar o organizationId em parâmetro se quiser reutilizar o script em múltiplas organizações.LogsO script atual não gera log por padrão. Recomendo adicionar logging simples (posso fornecer uma versão melhorada com log se precisar).Validação após deploymentApós a execução, verifique:Registro:reg

HKLM\Software\CiscoSecureClient
UmbrellaInstalled = 1
OrgId = SEU_ORG_ID_AQUI

Arquivo:

C:\ProgramData\Cisco\Cisco Secure Client\Umbrella\OrgInfo.json
C:\ProgramData\Cisco\Cisco Secure Client\Umbrella\data\OrgInfo.json

Serviços rodando:csc_umbrellaagent
csc_swgagent

No dashboard do Cisco Umbrella → Roaming Computers (o computador deve aparecer).

Avisos ImportantesO script remove instalações anteriores do Cisco Secure Client. Use com cuidado em ambientes de produção.
Teste primeiro em um grupo piloto (OU de teste).
O organizationId deve ser exatamente o mesmo configurado no seu tenant do Umbrella.
O instalador precisa estar presente em C:\Temp antes da execução da tarefa.

Contribuição / MelhoriasSugestões bem-vindas:Adicionar logging completo
Suporte a parâmetro de OrgID
Versão com PSAppDeployToolkit
Suporte a atualização automática de versão
Tratamento de erros mais robusto

AutorCriado para uso corporativo com Cisco Umbrella + Active Directory.Licença: MIT (ou a licença que preferir)Última atualização: Abril/2026


