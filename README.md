# Dotfiles - PowerShell Configuration

Configurações personalizadas do meu terminal Windows PowerShell (`oh-my-posh`, `eza`, atalhos e artes).

## 🚀 Restauração Rápida (PC Novo)

Em um computador recém-formatado, abra o PowerShell e execute o comando abaixo para instalar as ferramentas e restaurar tudo automaticamente:

```powershell
irm [https://raw.githubusercontent.com/webautopsy/dotfiles/main/install.ps1](https://raw.githubusercontent.com/webautopsy/dotfiles/main/install.ps1) | iex
```

## 🔄 Salvar Alterações (Máquina Atual)

Sempre que fizer modificações no seu `$PROFILE` ou nas artes/temas da pasta `.config`, atualize o repositório remoto rodando:

```powershell
push-config "sua mensagem de alteracao"
```
