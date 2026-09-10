# ==========================================
# ALIASES
# ==========================================
$ytdlp = "C:\tools\yt dlp\yt-dlp.exe"
$downloadsPath = "$HOME\Downloads"

# baixa e SEMPRE reconverte pra H.264/AAC, garantindo compatibilidade com qualquer plataforma
function y {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)

    $tempDir = "$env:TEMP\ytdlp-temp"

    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

    $tempTemplate = "$tempDir\%(title)s.%(ext)s"

    Write-Host "Baixando..." -ForegroundColor DarkGray

    & $ytdlp -f "bv*+ba/b" `
        --merge-output-format mp4 `
        -o $tempTemplate `
        @Args

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Falha ao baixar o video." -ForegroundColor DarkGray
        return
    }

    $downloadedFile = Get-ChildItem -Path $tempDir -Filter "*.mp4" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $downloadedFile) {
        Write-Host "Video baixado, mas o arquivo nao foi encontrado." -ForegroundColor DarkGray
        return
    }

    $nomeFinal = [System.IO.Path]::GetFileNameWithoutExtension($downloadedFile.Name)
    $saida = Join-Path $downloadsPath "$nomeFinal.mp4"

    Write-Host "Convertendo para formato compativel..." -ForegroundColor DarkGray

    ffmpeg -y -i "$($downloadedFile.FullName)" `
        -c:v libx264 `
        -c:a aac `
        -movflags +faststart `
        "$saida" 2>$null

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Falha ao converter o video." -ForegroundColor DarkGray
        return
    }

    Remove-Item $downloadedFile.FullName -Force -ErrorAction SilentlyContinue

    Write-Host "Pronto: $saida" -ForegroundColor White
}

function ya { & $ytdlp -x --audio-format mp3 -o "$downloadsPath\%(title)s.%(ext)s" @args }
function y720 { & $ytdlp -f "bv*[vcodec^=avc1][height<=720]+ba/b[height<=720]" --merge-output-format mp4 -o "$downloadsPath\%(title)s.%(ext)s" @args }

function yq {
    param([Parameter(Mandatory=$true)][string]$Url)

    Write-Host "Buscando qualidades disponiveis..." -ForegroundColor DarkGray
    $json = & $ytdlp -j $Url 2>$null | Select-Object -First 1
    $data = $json | ConvertFrom-Json

    $videoFormats = $data.formats |
        Where-Object { $_.vcodec -ne "none" -and $_.height } |
        Sort-Object -Property height -Descending -Unique

    if (-not $videoFormats) {
        Write-Host "Nenhum formato de video encontrado, baixando na melhor qualidade padrao." -ForegroundColor DarkGray
        & $ytdlp -o "$downloadsPath\%(title)s.%(ext)s" $Url
        return
    }

    $bestAudio = $data.formats |
        Where-Object { $_.acodec -ne "none" -and $_.vcodec -eq "none" } |
        Sort-Object -Property abr -Descending |
        Select-Object -First 1

    Write-Host ""
    Write-Host "Escolha a qualidade:" -ForegroundColor White
    $i = 1
    $map = @{}
    foreach ($f in $videoFormats) {
        Write-Host "  $i) $($f.height)p"
        $map[$i] = $f.format_id
        $i++
    }
    Write-Host ""

    $choice = Read-Host "Digite o numero"
    if (-not $map.ContainsKey([int]$choice)) {
        Write-Host "Opcao invalida." -ForegroundColor DarkGray
        return
    }

    $videoId = $map[[int]$choice]
    $formatString = if ($bestAudio) { "$videoId+$($bestAudio.format_id)" } else { $videoId }

    & $ytdlp -f $formatString --merge-output-format mp4 -o "$downloadsPath\%(title)s.%(ext)s" $Url
}

function yc {
    param(
        [Parameter(Mandatory=$true)][string]$Url,
        [Parameter(Mandatory=$true)][string]$Inicio,
        [Parameter(Mandatory=$true)][string]$Fim
    )
    & $ytdlp --download-sections "*$Inicio-$Fim" --force-keyframes-at-cuts -f "bv*[vcodec^=avc1]+ba/b" --merge-output-format mp4 -o "$downloadsPath\%(title)s.%(ext)s" $Url
}

# comprime um video para um tamanho alvo em MB - sempre le e salva na pasta Downloads
function ycomp {
    param(
        [Parameter(Mandatory=$true)][string]$Arquivo,
        [Parameter(Mandatory=$true)][double]$TamanhoMB
    )

    # se so foi passado o nome do arquivo (sem caminho), assume que esta na pasta Downloads
    $temCaminho = $Arquivo -match '[\\/]' -or $Arquivo -match '^[a-zA-Z]:'
    $caminhoCompleto = if ($temCaminho) { $Arquivo } else { Join-Path $downloadsPath $Arquivo }

    if (-not (Test-Path $caminhoCompleto)) {
        Write-Host "Arquivo nao encontrado: $caminhoCompleto" -ForegroundColor DarkGray
        return
    }

    $duration = [double](ffprobe -v error -show_entries format=duration -of csv=p=0 "$caminhoCompleto")
    if ($duration -le 0) {
        Write-Host "Nao foi possivel ler a duracao do video." -ForegroundColor DarkGray
        return
    }

    $audioBitrateKbps = 128
    $targetBitsTotal = $TamanhoMB * 8 * 1024 * 1024
    $targetBitrateKbps = [Math]::Floor(($targetBitsTotal / $duration / 1000) - $audioBitrateKbps)

    if ($targetBitrateKbps -lt 100) {
        Write-Host "Tamanho alvo muito pequeno para a duracao do video." -ForegroundColor DarkGray
        return
    }

    $nome = [System.IO.Path]::GetFileNameWithoutExtension($caminhoCompleto)
    $saida = Join-Path $downloadsPath "$nome-${TamanhoMB}MB.mp4"
    $logPrefix = Join-Path $env:TEMP "ycomp-pass"

    Write-Host "Comprimindo para ~${TamanhoMB}MB (bitrate: ${targetBitrateKbps}k)..." -ForegroundColor DarkGray

    ffmpeg -y -i "$caminhoCompleto" -c:v libx264 -b:v "${targetBitrateKbps}k" -pass 1 -passlogfile $logPrefix -an -f mp4 NUL 2>$null
    ffmpeg -y -i "$caminhoCompleto" -c:v libx264 -b:v "${targetBitrateKbps}k" -pass 2 -passlogfile $logPrefix -c:a aac -b:a "${audioBitrateKbps}k" -movflags +faststart "$saida" 2>$null

    Remove-Item "$logPrefix*" -Force -ErrorAction SilentlyContinue

    Write-Host "Pronto: $saida" -ForegroundColor White
}

function s { scrcpy @args }
function a { adb devices }

# junta N artes lado a lado e salva como a arte ativa do profile
function artm {
    param(
        [Parameter(Mandatory=$true)][string[]]$Files,
        [int]$Espaco = 4
    )

    $destino = "$HOME\.config\art.txt"

    foreach ($f in $Files) {
        if (-not (Test-Path $f)) {
            Write-Host "Arquivo nao encontrado: $f" -ForegroundColor DarkGray
            return
        }
    }

    if (Test-Path $destino) {
        Copy-Item $destino "$destino.bak" -Force
    }

    $todasLinhas = $Files | ForEach-Object { ,(Get-Content $_) }
    $maxLinhas = ($todasLinhas | ForEach-Object { $_.Count } | Measure-Object -Maximum).Maximum
    $larguras = $todasLinhas | ForEach-Object { ($_ | Measure-Object -Property Length -Maximum).Maximum }

    $separador = " " * $Espaco
    $resultado = @()

    for ($i = 0; $i -lt $maxLinhas; $i++) {
        $partes = for ($j = 0; $j -lt $Files.Count; $j++) {
            $linhas = $todasLinhas[$j]
            $texto = if ($i -lt $linhas.Count) { $linhas[$i] } else { "" }
            if ($j -lt $Files.Count - 1) { $texto.PadRight($larguras[$j]) } else { $texto }
        }
        $resultado += ($partes -join $separador)
    }

    $resultado | Set-Content -Path $destino -Encoding UTF8
    Write-Host "Arte combinada salva! (backup em art.txt.bak)" -ForegroundColor DarkGray
}

function art-undo {
    $destino = "$HOME\.config\art.txt"
    if (Test-Path "$destino.bak") {
        Copy-Item "$destino.bak" $destino -Force
        Write-Host "Arte anterior restaurada." -ForegroundColor DarkGray
    } else {
        Write-Host "Nenhum backup encontrado." -ForegroundColor DarkGray
    }
}

# ==========================================
# HELPERS DE COR
# ==========================================
function Write-Neon {
    param([string]$Text, [string]$HexColor = "#B0B0B0")
    $r = [Convert]::ToInt32($HexColor.Substring(1,2),16)
    $g = [Convert]::ToInt32($HexColor.Substring(3,2),16)
    $b = [Convert]::ToInt32($HexColor.Substring(5,2),16)
    Write-Host "$([char]27)[38;2;${r};${g};${b}m$Text$([char]27)[0m" -NoNewline
}

function Get-LerpColor {
    param([string]$HexA, [string]$HexB, [double]$T)
    $r1 = [Convert]::ToInt32($HexA.Substring(1,2),16); $g1 = [Convert]::ToInt32($HexA.Substring(3,2),16); $b1 = [Convert]::ToInt32($HexA.Substring(5,2),16)
    $r2 = [Convert]::ToInt32($HexB.Substring(1,2),16); $g2 = [Convert]::ToInt32($HexB.Substring(3,2),16); $b2 = [Convert]::ToInt32($HexB.Substring(5,2),16)
    $r = [int]($r1 + ($r2 - $r1) * $T)
    $g = [int]($g1 + ($g2 - $g1) * $T)
    $b = [int]($b1 + ($b2 - $b1) * $T)
    return "#{0:X2}{1:X2}{2:X2}" -f $r,$g,$b
}

function Write-PaletteGradientInline {
    param([string]$Text, [double]$Offset = 0)
    $stops = @("#303030", "#606060", "#B8B8B8", "#606060", "#303030")
    $len = $Text.Length
    for ($i = 0; $i -lt $len; $i++) {
        $pos = (($i / [Math]::Max(1, $len - 1)) + $Offset) % 1.0
        $segT = $pos * ($stops.Count - 1)
        $idx = [Math]::Min([int]$segT, $stops.Count - 2)
        $localT = $segT - $idx
        $color = Get-LerpColor -HexA $stops[$idx] -HexB $stops[$idx + 1] -T $localT
        Write-Neon $Text[$i] $color
    }
    Write-Host "$([char]27)[0m" -NoNewline
}

# ==========================================
# RENDERIZAÇÃO SIDE-BY-SIDE (FASTFETCH STYLE)
# ==========================================
$steel = "#8A93A0"
$gray  = "#3A3A3A"
$white = "#EDEDED"

$rightSide = @(
    { Write-Neon "▓▓ " $steel; Write-Neon "ANDROID" $white },
    { Write-Neon "┃" $gray; Write-Host -NoNewline "  "; Write-Neon "s" $steel; Write-Host -NoNewline "  →  scrcpy" },
    { Write-Neon "┗━ " $gray; Write-Neon "a" $steel; Write-Host -NoNewline "  →  adb devices" },
    { },
    { Write-Neon "▓▓ " $steel; Write-Neon "DOWNLOADS" $white },
    { Write-Neon "┃" $gray; Write-Host -NoNewline "  "; Write-Neon "y" $steel; Write-Host -NoNewline "     URL              →  completo " },
    { Write-Neon "┃" $gray; Write-Host -NoNewline "  "; Write-Neon "ya" $steel; Write-Host -NoNewline "    URL              →  só áudio" },
    { Write-Neon "┃" $gray; Write-Host -NoNewline "  "; Write-Neon "y720" $steel; Write-Host -NoNewline "  URL              →  720p" },
    { Write-Neon "┃" $gray; Write-Host -NoNewline "  "; Write-Neon "yq" $steel; Write-Host -NoNewline "    URL              →  escolher qualidade" },
    { Write-Neon "┃" $gray; Write-Host -NoNewline "  "; Write-Neon "yc" $steel; Write-Host -NoNewline "    URL 00:00 00:00  →  cortar trecho" },
    { Write-Neon "┗━ " $gray; Write-Neon "ycomp" $steel; Write-Host -NoNewline " nome.mp4 MB      →  comprimir" }
)

Write-Host ""
$artPath = "$HOME\.config\art.txt"

if (Test-Path $artPath) {
    $artLines = Get-Content $artPath
    $maxArtWidth = ($artLines | Measure-Object -Property Length -Maximum).Maximum
    $totalLines = [Math]::Max($artLines.Count, $rightSide.Count)
    $lineOffset = 0
    $espaco = "    "

    for ($i = 0; $i -lt $totalLines; $i++) {
        if ($i -lt $artLines.Count) {
            $line = $artLines[$i]
            Write-PaletteGradientInline -Text $line -Offset $lineOffset
            $padding = " " * ($maxArtWidth - $line.Length)
            Write-Host $padding -NoNewline
            $lineOffset += 0.08
        } else {
            Write-Host (" " * $maxArtWidth) -NoNewline
        }

        Write-Host $espaco -NoNewline

        if ($i -lt $rightSide.Count) {
            & $rightSide[$i]
        }

        Write-Host ""
    }
} else {
    foreach ($lineBlock in $rightSide) {
        & $lineBlock
        Write-Host ""
    }
}
Write-Host ""

# ==========================================
# OH MY POSH
# ==========================================
$ompPath = "$HOME\.config\oh-my-posh\lone.omp.json"
if (Test-Path $ompPath) {
    oh-my-posh init pwsh --config $ompPath | Invoke-Expression
}

# ==========================================
# EZA
# ==========================================
if (Test-Path Alias:ls) { Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue }

function ls  { eza --icons @args }
function ll  { eza --icons -l @args }
function la  { eza --icons -la @args }
function lt  { eza --icons --tree @args }


# ==========================================
# BACKUP AUTOMÁTICO (DOTFILES)
# ==========================================
function push-config {
    param([string]$Message = "Atualizacao de configuracoes")

    $dotfiles = "$HOME\dotfiles"

    # Copia o PROFILE e a pasta .config atualizados
    Copy-Item $PROFILE "$dotfiles\Microsoft.PowerShell_profile.ps1" -Force
    Copy-Item -Recurse "$HOME\.config" "$dotfiles\" -Force

    # Envia as alteracoes para o GitHub
    Push-Location $dotfiles
    git add .
    git commit -m $Message
    git push
    Pop-Location

    Write-Host "Configuracoes salvas no GitHub com sucesso!" -ForegroundColor Green
}