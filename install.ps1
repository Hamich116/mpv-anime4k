# ====================================================================
# mpv + ModernZ + Anime4K — Автоматический установщик
# Репозиторий: https://github.com/Hamich116/mpv-anime4k
# ====================================================================
$ErrorActionPreference = 'Stop'
$targetDir = "C:\mpv"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   Установка mpv + ModernZ + Anime4K" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Целевая папка: $targetDir" -ForegroundColor Gray

if (-not (Test-Path $targetDir)) {
    New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
}

# 1. Скачивание свежего билда mpv
Write-Host "`n[1/4] Загрузка официального 64-битного mpv (shinchiro)..." -ForegroundColor Yellow
$rel = Invoke-RestMethod -Uri "https://api.github.com/repos/shinchiro/mpv-winbuild-cmake/releases/latest" -Headers @{'User-Agent'='PowerShell'}
$asset = @($rel.assets) | Where-Object { $_.name -like 'mpv-x86_64-v3-*.7z' -or $_.name -like 'mpv-x86_64-*.7z' } | Where-Object { $_.name -notlike '*dev*' } | Select-Object -First 1

if (-not $asset) {
    throw "Не удалось получить ссылку на релиз mpv с GitHub."
}

$tmp7z = "$env:TEMP\mpv_download.7z"
curl.exe -sL $asset.browser_download_url -o $tmp7z
tar.exe -xf $tmp7z -C $targetDir
Remove-Item $tmp7z -Force -ErrorAction SilentlyContinue

# 2. Развертывание конфигурации (portable_config)
Write-Host "[2/4] Развертывание ModernZ, thumbfast и шейдеров Anime4K..." -ForegroundColor Yellow

$localConfig = Join-Path $PSScriptRoot "portable_config"
if ($PSScriptRoot -and (Test-Path $localConfig)) {
    # Запуск из локально клонированного репозитория
    Copy-Item $localConfig -Destination $targetDir -Recurse -Force
} else {
    # Запуск через irm ... | iex (скачивание из репозитория)
    $zipUrl = "https://github.com/Hamich116/mpv-anime4k/archive/refs/heads/main.zip"
    $tmpZip = "$env:TEMP\mpv_repo.zip"
    curl.exe -sL $zipUrl -o $tmpZip
    tar.exe -xf $tmpZip -C $env:TEMP
    Copy-Item "$env:TEMP\mpv-anime4k-main\portable_config" -Destination $targetDir -Recurse -Force
    Remove-Item $tmpZip, "$env:TEMP\mpv-anime4k-main" -Recurse -Force -ErrorAction SilentlyContinue
}

# 3. Создание ярлыка на Рабочем столе
Write-Host "[3/4] Создание ярлыка на Рабочем столе..." -ForegroundColor Yellow
$wsh = New-Object -ComObject WScript.Shell
$sc = $wsh.CreateShortcut("$env:USERPROFILE\Desktop\mpv.lnk")
$sc.TargetPath = "$targetDir\mpv.exe"
$sc.WorkingDirectory = $targetDir
$sc.IconLocation = "$targetDir\mpv.exe,0"
$sc.Description = "mpv + ModernZ + Anime4K"
$sc.Save()

# 4. Регистрация в контекстном меню Windows
Write-Host "[4/4] Добавление пункта «Play with mpv» в контекстное меню..." -ForegroundColor Yellow
$mpvExe = "$targetDir\mpv.exe"
$mpvCmd = "`"$mpvExe`" -- `"%1`""
$mpvFolderCmd = "`"$mpvExe`" -- `"%V`""

$locations = @(
    "SystemFileAssociations\video\shell\mpv.play",
    "SystemFileAssociations\audio\shell\mpv.play",
    "Directory\shell\mpv.play"
)
foreach ($loc in $locations) {
    $p = "HKCU:\Software\Classes\$loc"
    New-Item -Path $p -Force | Out-Null
    Set-ItemProperty -Path $p -Name "(default)" -Value "Play with mpv"
    Set-ItemProperty -Path $p -Name "Icon" -Value "$mpvExe,0"
    $c = "$p\command"
    New-Item -Path $c -Force | Out-Null
    Set-ItemProperty -Path $c -Name "(default)" -Value $mpvCmd
}

$bg = "HKCU:\Software\Classes\Directory\Background\shell\mpv.play"
New-Item -Path $bg -Force | Out-Null
Set-ItemProperty -Path $bg -Name "(default)" -Value "Play with mpv"
Set-ItemProperty -Path $bg -Name "Icon" -Value "$mpvExe,0"
$bgCmd = "$bg\command"
New-Item -Path $bgCmd -Force | Out-Null
Set-ItemProperty -Path $bgCmd -Name "(default)" -Value $mpvFolderCmd

New-Item -Path "HKCU:\Software\Classes\SystemFileAssociations\video\OpenWithList\mpv.exe" -Force | Out-Null
New-Item -Path "HKCU:\Software\Classes\SystemFileAssociations\audio\OpenWithList\mpv.exe" -Force | Out-Null

$exts = @('.mkv', '.mp4', '.avi', '.mov', '.webm', '.flv', '.wmv', '.ts', '.m2ts')
foreach ($ext in $exts) {
    $extKey = "HKCU:\Software\Classes\SystemFileAssociations\$ext\shell\mpv.play"
    New-Item -Path $extKey -Force | Out-Null
    Set-ItemProperty -Path $extKey -Name "(default)" -Value "Play with mpv"
    Set-ItemProperty -Path $extKey -Name "Icon" -Value "$mpvExe,0"
    $extCmd = "$extKey\command"
    New-Item -Path $extCmd -Force | Out-Null
    Set-ItemProperty -Path $extCmd -Name "(default)" -Value $mpvCmd
}

try {
    Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;
    public class ShellNotifyInstall {
        [DllImport("shell32.dll")]
        public static extern void SHChangeNotify(int wEventId, int uFlags, IntPtr dwItem1, IntPtr dwItem2);
    }
"@
    [ShellNotifyInstall]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)
} catch {}

Write-Host "`n[✓] Установка успешно завершена!" -ForegroundColor Green
Write-Host "Плеер готов к использованию в $targetDir" -ForegroundColor Green
