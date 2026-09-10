# ==========================================
# SCRIPT DE RESTAURAÇÃO DE AMBIENTE (DOTFILES)
# ==========================================

# 1. Instalar dependências essenciais via winget
Write-Host "Instalando ferramentas essenciais..." -ForegroundColor Cyan
winget install Git.Git JanDeDobbeleer.OhMyPosh eza --accept-source-agreements --accept-package-agreements

# 2. Clonar o repositório de dotfiles do GitHub
$dotfiles = "$HOME\dotfiles"
if (-not (Test-Path $dotfiles)) {
    Write-Host "Baixando dotfiles do GitHub..." -ForegroundColor Cyan
    git clone https://github.com/webautopsy/dotfiles.git $dotfiles
}

# 3. Restaurar a pasta .config (temas, artes e configs)
Write-Host "Restaurando a pasta .config..." -ForegroundColor Cyan
Copy-Item -Recurse "$dotfiles\.config" "$HOME\" -Force

# 4. Criar o diretório do PROFILE (caso não exista) e restaurar o arquivo
Write-Host "Restaurando o perfil do PowerShell..." -ForegroundColor Cyan
$profileDir = Split-Path $PROFILE
New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
Copy-Item "$dotfiles\Microsoft.PowerShell_profile.ps1" $PROFILE -Force

Write-Host "`nAmbiente restaurado com sucesso! Feche e abra o terminal." -ForegroundColor Green
