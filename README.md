# Dotfiles - PowerShell Configuration

Configurações personalizadas do meu terminal Windows PowerShell (`oh-my-posh`, `eza`, atalhos e artes).

## 🚀 Restauração Rápida (PC Novo)

Em um computador recém-formatado, abra o PowerShell e execute o comando abaixo para instalar as ferramentas e restaurar tudo automaticamente:

```powershell
irm https://raw.githubusercontent.com/webautopsy/dotfiles/main/install.ps1 | iex
```

O script instala via `winget`:
- Git
- oh-my-posh
- eza
- yt-dlp

E restaura a pasta `.config` (temas, artes) e o `$PROFILE` do PowerShell.

> **Nota:** os comandos de download (`y`, `ya`, `y720`, `yq`, `yc`, `ycomp`) usam por padrão o yt-dlp instalado em `C:\tools\yt dlp\yt-dlp.exe`. Se esse caminho não existir na máquina, o profile cai automaticamente para o `yt-dlp` do PATH (instalado pelo winget acima).

## 🔄 Salvar Alterações (Máquina Atual)

Sempre que fizer modificações no seu `$PROFILE` ou nas artes/temas da pasta `.config`, atualize o repositório remoto rodando:

```powershell
push-config "sua mensagem de alteracao"
```
