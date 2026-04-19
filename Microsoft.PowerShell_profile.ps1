# ═══════════════════════════════════════════════════════════════
#  POWERSHELL PROFILE 
#  Catppuccin Mocha | Zoxide | Oh-My-Posh | PSReadLine
# ═══════════════════════════════════════════════════════════════

# ─── 1. PSREADLINE ─────────────────────────────────────────────
$_hasPredictor = Get-Module -Name CompletionPredictor -ListAvailable
if ($_hasPredictor) {
    Import-Module CompletionPredictor -ErrorAction SilentlyContinue
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
} else {
    Set-PSReadLineOption -PredictionSource History
}
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -Colors @{
    Command            = '#89b4fa'
    Comment            = '#585b70'
    ContinuationPrompt = '#cdd6f4'
    Default            = '#cdd6f4'
    Emphasis           = '#f5c2e7'
    Error              = '#f38ba8'
    InlinePrediction   = '#45475a'
    Keyword            = '#cba6f7'
    Member             = '#89b4fa'
    Number             = '#fab387'
    Operator           = '#89dceb'
    Parameter          = '#f2cdcd'
    String             = '#a6e3a1'
    Type               = '#f9e2af'
    Variable           = '#89b4fa'
}
Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Tab       -Function MenuComplete
Set-PSReadLineKeyHandler -Key Ctrl+d    -Function DeleteChar

# ─── 2. TERMINAL-ICONS (lazy load) ─────────────────────────────
function global:ls {
    if (-not (Get-Module Terminal-Icons)) {
        Import-Module Terminal-Icons -ErrorAction SilentlyContinue
    }
    Microsoft.PowerShell.Management\Get-ChildItem @args
}
Set-Alias -Name dir -Value ls -Option AllScope -Force

# ─── 3. ZOXIDE ─────────────────────────────────────────────────
$_zCache = "$env:TEMP\zoxide_init.ps1"
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    if (-not (Test-Path $_zCache)) { zoxide init powershell | Set-Content $_zCache }
    . $_zCache
}

# ─── 4. OH-MY-POSH ─────────────────────────────────────────────
$_themePath = Join-Path (Split-Path $PROFILE) 'catppuccin-burak.omp.json'

oh-my-posh init pwsh --config "C:\dotFiles\PoshThemes\jandedobbeleer.omp.json" | Invoke-Expression


# ─── 5. WORKFLOW ───────────────────────────────────────────────
function mkcd {
    param([string]$name)
    New-Item -ItemType Directory -Path $name -Force | Out-Null
    Set-Location $name
}

function Set-Theme {
    param([string]$name)
    $path = "C:\dotFiles\PoshThemes\$name.omp.json"
    if (Test-Path $path) {
        # Mevcut oh-my-posh ayarını temizle ve yenisini yükle
        oh-my-posh init pwsh --config $path | Invoke-Expression
    } else {
        Write-Host "Tema bulunamadı: $name . C:\PoshThemes klasörünü kontrol et." -ForegroundColor Red
    }
}

function kill-port {
    param([int]$port)
    $conns = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    if (-not $conns) {
        Write-Host "No process on port $port" -ForegroundColor Yellow
        return
    }
    $conns | ForEach-Object {
        Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue
        Write-Host "Killed PID $($_.OwningProcess) on port $port" -ForegroundColor Green
    }
}

function envs {
    param([string]$filter = '')
    $vars = Get-ChildItem Env: | Sort-Object Name
    if ($filter) {
        $vars = $vars | Where-Object { $_.Name -like "*$filter*" -or $_.Value -like "*$filter*" }
    }
    $vars | Format-Table -AutoSize
}

function proj  { Set-Location "$HOME\Documents\projects" }

function which {
    param([string]$cmd)
    (Get-Command $cmd -ErrorAction SilentlyContinue).Source
}

# ─── 7. SYSTEM / NETWORK ───────────────────────────────────────
function ports {
    $procs = @{}
    Get-Process -EA SilentlyContinue | ForEach-Object { $procs[$_.Id] = $_ }
    Get-NetTCPConnection -State Listen |
        Select-Object LocalPort,
            @{Name='Process'; Expression={ $procs[$_.OwningProcess].ProcessName }},
            @{Name='Path';    Expression={ $procs[$_.OwningProcess].Path }},
            OwningProcess |
        Sort-Object LocalPort | Format-Table -AutoSize
}

function top {
    Write-Host "`n CPU Top 10" -ForegroundColor Cyan
    Get-Process | Sort-Object CPU -Descending |
        Select-Object -First 10 Name, CPU, WorkingSet | Format-Table -AutoSize
    Write-Host "`n RAM Top 10" -ForegroundColor Cyan
    Get-Process | Sort-Object WorkingSet -Descending |
        Select-Object -First 10 Name,
            @{Name='RAM(MB)'; Expression={ [math]::Round($_.WorkingSet / 1MB, 1) }} |
        Format-Table -AutoSize
}

function tail {
    param([string]$file, [int]$n = 50, [switch]$f)
    if ($f) { Get-Content $file -Tail $n -Wait }
    else    { Get-Content $file -Tail $n }
}

function du {
    param([string]$dir = '.')
    Get-ChildItem $dir | ForEach-Object {
        $size = (Get-ChildItem $_.FullName -Recurse -EA SilentlyContinue | Measure-Object Length -Sum).Sum
        [PSCustomObject]@{ Name = $_.Name; 'Size(MB)' = [math]::Round($size / 1MB, 2) }
    } | Sort-Object 'Size(MB)' -Descending | Format-Table -AutoSize
}

function sysinfo {
    $os   = Get-CimInstance Win32_OperatingSystem
    $cpu  = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name
    $disk = Get-PSDrive C | Select-Object Used, Free
    $up   = [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalHours, 1)
    Write-Host ""
    Write-Host "  SYSTEM INFO" -ForegroundColor Cyan
    Write-Host "  OS   : $($os.Caption)"
    Write-Host "  CPU  : $cpu"
    Write-Host "  RAM  : $([math]::Round($os.FreePhysicalMemory / 1MB, 1)) GB free"
    Write-Host "  Disk : $([math]::Round($disk.Used / 1GB, 1)) GB used / $([math]::Round($disk.Free / 1GB, 1)) GB free"
    Write-Host "  Up   : ${up}h"
    Write-Host ""
}

# ─── 8. PRESERVED ──────────────────────────────────────────────
function clean-dotnet {
    Write-Host "Cleaning bin & obj..." -ForegroundColor Cyan
    Get-ChildItem -Recurse -EA SilentlyContinue | Where-Object { $_.Name -in 'bin','obj' } | Remove-Item -Recurse -Force
    Write-Host "Done." -ForegroundColor Green
}

function dclean {
    docker system prune -a --volumes -f
    Write-Host "Docker system clean." -ForegroundColor Magenta
}

function sql-reset {
    Restart-Service -Name 'MSSQL$SQLEXPRESS' -Force
    Write-Host "SQL Server Express restarted." -ForegroundColor Yellow
}

Set-Alias -Name c -Value Clear-Host
Set-Alias -Name v -Value nvim
function c.      { code . }
function reload  { . $PROFILE; Write-Host "Profile reloaded." -ForegroundColor Green }
function myip    { (Invoke-RestMethod https://api.ipify.org) }
function weather { param([string]$city = 'Istanbul') curl "wttr.in/$city?m" }

# ─── 9. NAVIGATION ─────────────────────────────────────────────
function ..   { Set-Location .. }
function ...  { Set-Location ../.. }
function .... { Set-Location ../../.. }

function up {
    param([int]$n = 1)
    Set-Location (('../' * $n).TrimEnd('/'))
}

function touch {
    param([string]$file)
    if (Test-Path $file) { (Get-Item $file).LastWriteTime = Get-Date }
    else { New-Item -ItemType File -Path $file | Out-Null }
}

function open {
    param([string]$path = '.') Invoke-Item $path
}

function ff {
    param([string]$pattern, [string]$dir = '.')
    Get-ChildItem $dir -Recurse -EA SilentlyContinue |
        Where-Object { $_.Name -like "*$pattern*" } |
        ForEach-Object { Write-Host $_.FullName }
}

function grep {
    param([string]$pattern, [string]$path = '.', [switch]$r)
    $files = if ($r) { Get-ChildItem $path -Recurse -File -EA SilentlyContinue }
             else    { Get-ChildItem $path -File -EA SilentlyContinue }
    $files | Select-String $pattern | ForEach-Object {
        Write-Host $_.Filename -ForegroundColor Cyan -NoNewline
        Write-Host ":$($_.LineNumber)  " -ForegroundColor DarkGray -NoNewline
        Write-Host $_.Line.Trim()
    }
}

function recent {
    param([int]$n = 10, [string]$dir = '.')
    Get-ChildItem $dir -Recurse -File -EA SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First $n |
        Select-Object LastWriteTime, FullName | Format-Table -AutoSize
}

function biggest {
    param([string]$dir = '.', [int]$n = 10)
    Get-ChildItem $dir -Recurse -File -EA SilentlyContinue |
        Sort-Object Length -Descending | Select-Object -First $n |
        Select-Object @{N='Size(MB)';E={[math]::Round($_.Length/1MB,2)}}, FullName |
        Format-Table -AutoSize
}

function backup {
    param([string]$file)
    $dest = "$file.$(Get-Date -Format 'yyyyMMdd-HHmmss').bak"
    Copy-Item $file $dest
    Write-Host "-> $dest" -ForegroundColor Green
}

Set-Alias -Name cdb -Value Pop-Location -Force

# ─── 10. SYSTEM EXTENDED ───────────────────────────────────────
function mem {
    $os   = Get-CimInstance Win32_OperatingSystem
    $tot  = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    $free = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
    $used = [math]::Round($tot - $free, 1)
    $pct  = [math]::Round(($used / $tot) * 100, 0)
    $bar  = ('█' * [math]::Round($pct / 5)).PadRight(20, '░')
    Write-Host "  RAM  [$bar] $pct%  ($used / $tot GB)" -ForegroundColor Cyan
}

function drives {
    Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null } | ForEach-Object {
        $tot = $_.Used + $_.Free
        if ($tot -eq 0) { return }
        $pct = [math]::Round(($_.Used / $tot) * 100, 0)
        $bar = ('█' * [math]::Round($pct / 5)).PadRight(20, '░')
        Write-Host "  $($_.Name):  [$bar] $pct%  ($([math]::Round($_.Used/1GB,1)) / $([math]::Round($tot/1GB,1)) GB)" -ForegroundColor Yellow
    }
}

function pkill {
    param([string]$name)
    Get-Process -Name "*$name*" -EA SilentlyContinue | ForEach-Object {
        Stop-Process $_ -Force
        Write-Host "Killed $($_.Name) [$($_.Id)]" -ForegroundColor Red
    }
}

function pgrep {
    param([string]$name)
    Get-Process -Name "*$name*" -EA SilentlyContinue |
        Select-Object Id, Name, CPU,
            @{N='RAM(MB)';E={[math]::Round($_.WorkingSet/1MB,1)}}, Path |
        Format-Table -AutoSize
}

function admin {
    Start-Process pwsh -Verb RunAs -ArgumentList "-NoExit -Command `"Set-Location '$PWD'`""
}

function path {
    $env:PATH -split ';' | Where-Object { $_ } | ForEach-Object { Write-Host $_ }
}

function hosts { notepad "$env:SystemRoot\System32\drivers\etc\hosts" }

function flush-dns {
    ipconfig /flushdns | Out-Null
    Write-Host "DNS cache flushed." -ForegroundColor Green
}

function localip {
    Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object { $_.InterfaceAlias -notlike '*Loopback*' } |
        Select-Object InterfaceAlias, IPAddress | Format-Table -AutoSize
}

function wifi-info { netsh wlan show interfaces | Select-String 'SSID|Signal|Radio type' }

function wifi-pass {
    param([string]$ssid = '')
    if ($ssid) {
        netsh wlan show profile name="$ssid" key=clear | Select-String 'Key Content'
    } else {
        (netsh wlan show profiles) -match 'All User Profile' |
            ForEach-Object { ($_ -split ':')[1].Trim() }
    }
}

function net-test {
    foreach ($t in '8.8.8.8','1.1.1.1','google.com') {
        $r = Test-Connection $t -Count 1 -EA SilentlyContinue
        if ($r) { Write-Host "  $t`t OK  ($($r.Latency)ms)" -ForegroundColor Green }
        else    { Write-Host "  $t`t FAIL"                  -ForegroundColor Red   }
    }
}

function dns-lookup {
    param([string]$host)
    Resolve-DnsName $host | Select-Object Name, Type, IPAddress | Format-Table -AutoSize
}

function svcs {
    param([string]$filter = '')
    $s = Get-Service | Where-Object Status -eq Running
    if ($filter) { $s = $s | Where-Object { $_.Name -like "*$filter*" -or $_.DisplayName -like "*$filter*" } }
    $s | Select-Object Name, DisplayName | Sort-Object Name | Format-Table -AutoSize
}

function evterr {
    param([int]$n = 20)
    Get-WinEvent -LogName System -MaxEvents 500 -EA SilentlyContinue |
        Where-Object { $_.Level -le 2 } | Select-Object -First $n |
        Select-Object TimeCreated, LevelDisplayName, Message | Format-Table -Wrap -AutoSize
}

function startup-items {
    Get-CimInstance Win32_StartupCommand |
        Select-Object Name, Command, Location | Format-Table -AutoSize
}

function winget-up { winget upgrade --all --silent }

function env-set {
    param([string]$name, [string]$value)
    [Environment]::SetEnvironmentVariable($name, $value, 'User')
    Set-Item "env:$name" $value
    Write-Host "Set $name (persistent)" -ForegroundColor Green
}

# ─── 11. UTILITIES ─────────────────────────────────────────────
function b64  { param([string]$t) [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($t)) }
function b64d { param([string]$t) [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($t)) }

function hash {
    param([string]$input, [string]$algo = 'SHA256')
    if (Test-Path $input -EA SilentlyContinue) { (Get-FileHash $input -Algorithm $algo).Hash }
    else {
        $h = [Security.Cryptography.HashAlgorithm]::Create($algo)
        ($h.ComputeHash([Text.Encoding]::UTF8.GetBytes($input)) | ForEach-Object { $_.ToString('x2') }) -join ''
    }
}

function cb {
    if ($MyInvocation.ExpectingInput) { $input | Set-Clipboard }
    else { Get-Clipboard }
}

function uuid { [guid]::NewGuid().ToString() }

function genpass {
    param([int]$length = 16)
    $c = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*'
    -join (1..$length | ForEach-Object { $c[(Get-Random -Max $c.Length)] })
}

function epoch { [int64](([datetime]::UtcNow - [datetime]'1970-01-01').TotalSeconds) }
function now   { Get-Date -Format 'yyyy-MM-dd HH:mm:ss' }

function urlencode { param([string]$t) [Uri]::EscapeDataString($t) }
function urldecode { param([string]$t) [Uri]::UnescapeDataString($t) }

function json-fmt { $input | ConvertFrom-Json | ConvertTo-Json -Depth 10 }

function stopwatch {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    Write-Host "Press any key to stop..." -ForegroundColor Cyan
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    $sw.Stop()
    Write-Host "Elapsed: $($sw.Elapsed.ToString('hh\:mm\:ss\.fff'))" -ForegroundColor Green
}

function timer {
    param([int]$seconds)
    $end = (Get-Date).AddSeconds($seconds)
    while ((Get-Date) -lt $end) {
        $left = [math]::Ceiling(($end - (Get-Date)).TotalSeconds)
        Write-Host "`r  $left s remaining...  " -NoNewline -ForegroundColor Yellow
        Start-Sleep -Milliseconds 250
    }
    Write-Host "`r  Done!                  " -ForegroundColor Green
    [console]::Beep(880, 400)
}

function note {
    param([string]$text = '')
    $f = "$HOME\.notes.md"
    if (-not $text) { if (Test-Path $f) { Get-Content $f } else { Write-Host "No notes." }; return }
    "- [$(Get-Date -Format 'yyyy-MM-dd HH:mm')] $text" | Add-Content $f
    Write-Host "Saved." -ForegroundColor Green
}

function calc { param([string]$expr) Invoke-Expression $expr }

function colortest {
    'Black','DarkBlue','DarkGreen','DarkCyan','DarkRed','DarkMagenta','DarkYellow','Gray',
    'DarkGray','Blue','Green','Cyan','Red','Magenta','Yellow','White' | ForEach-Object {
        Write-Host ("  {0,-14}" -f $_) -ForegroundColor $_ -NoNewline
    }
    Write-Host ""
}

function ep {
    if (Get-Command nvim -EA SilentlyContinue) { nvim $PROFILE }
    else { code $PROFILE }
}

function cmds {
    $sections = [ordered]@{
        'NAVIGATION' = @(
            @('..',          'cd ..'),
            @('...',         'cd ../..'),
            @('....',        'cd ../../..'),
            @('up <n>',      'N seviye yukarı çık'),
            @('touch',       'dosya oluştur / timestamp güncelle'),
            @('open',        'Explorer ile aç'),
            @('ff',          'dosya bul: ff <pattern>'),
            @('grep',        'içerik ara: grep <pat> [dir] [-r]'),
            @('recent',      'son değişen dosyalar'),
            @('biggest',     'en büyük dosyalar'),
            @('backup',      'dosyayı .bak olarak yedekle'),
            @('cdb',         'önceki dizine dön (Pop-Location)'),
            @('tree',        'renkli dizin ağacı [depth=3]'),
            @('count',       'dosya/klasör sayısı ve toplam boyut [-r]'),
            @('ls-size',     'boyuta göre sıralı ls'),
            @('find-large',  'büyük dosyaları bul: find-large 100 [dir]'),
            @('find-old',    'eski dosyaları bul: find-old 30 [dir]')
        )
        'SİSTEM' = @(
            @('sysinfo',       'OS/CPU/RAM/Disk özet'),
            @('cpu',           'CPU yük bar + çekirdek bilgisi'),
            @('mem',           'RAM kullanım bar'),
            @('drives',        'tüm sürücüler bar'),
            @('battery',       'batarya durumu'),
            @('top',           'CPU/RAM top 10 process'),
            @('disk-io',       'disk okuma/yazma anlık'),
            @('bandwidth',     'ağ bant genişliği anlık (1s)'),
            @('ports',         'dinleyen portlar + process'),
            @('kill-port',     'porta göre process öldür'),
            @('pkill',         'isme göre process öldür'),
            @('pgrep',         'process ara'),
            @('proc-tree',     'process hiyerarşisi'),
            @('watch',         'komutu N sn tekrarla: watch {cmd} 2'),
            @('svcs',          'çalışan servisler [filter]'),
            @('evterr',        'sistem hata logları'),
            @('last-logons',   'son oturum açma olayları'),
            @('startup-items', 'başlangıç öğeleri'),
            @('schtasks-list', 'zamanlanmış görevler'),
            @('admin',         'mevcut dizinde admin PS aç'),
            @('winget-up',     'tüm paketleri güncelle')
        )
        'AĞ' = @(
            @('localip',        'yerel IP adresleri'),
            @('myip',           'public IP'),
            @('iface',          'ağ arayüzleri detaylı (IP/MAC/GW)'),
            @('netconn',        'aktif bağlantılar + process [-all]'),
            @('scan-port',      'port erişilebilir mi: scan-port host port'),
            @('arp-table',      'ARP önbelleği'),
            @('shares',         'ağ paylaşımları'),
            @('net-test',       'internet bağlantı testi'),
            @('dns-lookup',     'DNS sorgusu'),
            @('flush-dns',      'DNS cache temizle'),
            @('wifi-info',      'Wi-Fi bağlantı bilgisi'),
            @('wifi-pass',      'kayıtlı Wi-Fi şifreleri'),
            @('hosts',          'hosts dosyasını aç'),
            @('path',           'PATH girdilerini listele'),
            @('firewall-rules', 'güvenlik duvarı kuralları [filter] [-dir]'),
            @('weather',        'hava durumu [şehir]')
        )
        'GÜVENLİK' = @(
            @('who',          'aktif oturumlar'),
            @('last-logons',  'son oturum açma olayları'),
            @('firewall-rules','güvenlik duvarı kuralları'),
            @('shares',       'ağ paylaşımları')
        )
        'ARAÇLAR' = @(
            @('b64 / b64d',       'Base64 encode / decode'),
            @('hash',             'dosya/string hash (SHA256)'),
            @('cb',               'clipboard kopyala/yapıştır'),
            @('uuid',             'yeni GUID üret'),
            @('genpass [n]',      'rastgele şifre üret'),
            @('epoch',            'Unix timestamp'),
            @('now',              'tarihi yyyy-MM-dd HH:mm:ss'),
            @('urlencode/decode', 'URL encode/decode'),
            @('json-fmt',         'JSON güzelleştir (pipe)'),
            @('calc <expr>',      'hesap: calc 2+2*10'),
            @('stopwatch',        'kronometre'),
            @('timer <sn>',       'geri sayım'),
            @('note [metin]',     '~\.notes.md dosyasına not ekle'),
            @('colortest',        'terminal renk paleti')
        )
        'GENEL' = @(
            @('mkcd',       'klasör oluştur + gir'),
            @('du',         'klasör boyutları'),
            @('tail',       'dosya sonu [-f izle]'),
            @('envs',       'env değişkenleri [filter]'),
            @('env-set',    'kalıcı env değişkeni ayarla'),
            @('which',      'komut yolunu bul'),
            @('proj',       '~/Documents/projects dizinine git'),
            @('reload',     'profili yeniden yükle'),
            @('ep',         'profili editörde aç'),
            @('c.',         'VS Code ile mevcut dizini aç'),
            @('Set-Theme',  'oh-my-posh teması değiştir'),
            @('cmds',       'bu listeyi göster')
        )
        'HIZLI AÇILIŞ' = @(
            @('resmon',     'Resource Monitor'),
            @('perfmon',    'Performance Monitor'),
            @('svcmgr',     'Services (services.msc)'),
            @('diskmgmt',   'Disk Management'),
            @('taskschd',   'Task Scheduler'),
            @('devmgmt',    'Device Manager'),
            @('eventlog',   'Event Viewer'),
            @('msinfo',     'System Information'),
            @('sfc-scan',   'sfc /scannow (admin)'),
            @('dism-check', 'DISM health check (admin)')
        )
    }

    foreach ($section in $sections.Keys) {
        Write-Host ""
        Write-Host "  $section" -ForegroundColor Magenta
        Write-Host "  $('─' * 40)" -ForegroundColor DarkGray
        foreach ($item in $sections[$section]) {
            Write-Host ("  {0,-22}" -f $item[0]) -ForegroundColor Cyan -NoNewline
            Write-Host $item[1] -ForegroundColor DarkGray
        }
    }
    Write-Host ""
}

# ─── 12. SYSTEM PRO ────────────────────────────────────────────

function cpu {
    $proc = Get-CimInstance Win32_Processor
    $load = ($proc | Measure-Object LoadPercentage -Average).Average
    $cores   = ($proc | Measure-Object NumberOfCores -Sum).Sum
    $threads = ($proc | Measure-Object NumberOfLogicalProcessors -Sum).Sum
    $bar  = ('█' * [math]::Round($load / 5)).PadRight(20, '░')
    Write-Host "  CPU  [$bar] $load%  ($cores cores / $threads threads)" -ForegroundColor Green
    Write-Host "  Name : $(($proc | Select-Object -First 1).Name)" -ForegroundColor DarkGray
}

function battery {
    $b = Get-CimInstance Win32_Battery -EA SilentlyContinue
    if (-not $b) { Write-Host "  No battery." -ForegroundColor DarkGray; return }
    $pct    = $b.EstimatedChargeRemaining
    $status = switch ($b.BatteryStatus) { 1{'Discharging'} 2{'AC / Full'} 3{'Charging'} default{'Unknown'} }
    $color  = if ($pct -gt 50) {'Green'} elseif ($pct -gt 20) {'Yellow'} else {'Red'}
    $bar    = ('█' * [math]::Round($pct / 5)).PadRight(20, '░')
    Write-Host "  BAT  [$bar] $pct%  ($status)" -ForegroundColor $color
}

function disk-io {
    Get-CimInstance Win32_PerfFormattedData_PerfDisk_LogicalDisk |
        Where-Object { $_.Name -ne '_Total' } |
        Select-Object Name,
            @{N='Read KB/s'; E={[math]::Round($_.DiskReadBytesPerSec/1KB,1)}},
            @{N='Write KB/s';E={[math]::Round($_.DiskWriteBytesPerSec/1KB,1)}},
            @{N='Queue';     E={$_.CurrentDiskQueueLength}} |
        Format-Table -AutoSize
}

function bandwidth {
    $a = Get-NetAdapterStatistics | Where-Object { (Get-NetAdapter -Name $_.Name -EA SilentlyContinue).Status -eq 'Up' }
    Start-Sleep 1
    $b = Get-NetAdapterStatistics | Where-Object { (Get-NetAdapter -Name $_.Name -EA SilentlyContinue).Status -eq 'Up' }
    Write-Host ""
    $a | ForEach-Object {
        $n  = $_.Name
        $bv = $b | Where-Object Name -eq $n
        $rx = [math]::Round(($bv.ReceivedBytes - $_.ReceivedBytes) / 1KB, 1)
        $tx = [math]::Round(($bv.SentBytes     - $_.SentBytes)    / 1KB, 1)
        Write-Host ("  {0,-20}  RX: {1,8} KB/s   TX: {2,8} KB/s" -f $n, $rx, $tx) -ForegroundColor Cyan
    }
    Write-Host ""
}

function netconn {
    param([switch]$all)
    $procs  = @{}
    Get-Process -EA SilentlyContinue | ForEach-Object { $procs[$_.Id] = $_ }
    $states = if ($all) { @('Established','Listen','TimeWait','CloseWait') } else { @('Established') }
    Get-NetTCPConnection -State $states -EA SilentlyContinue |
        Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State,
            @{N='Process'; E={ $procs[$_.OwningProcess].Name }},
            @{N='PID';     E={ $_.OwningProcess }} |
        Sort-Object State, Process | Format-Table -AutoSize
}

function scan-port {
    param([string]$target, [int]$port, [int]$timeout = 1000)
    $tcp  = [System.Net.Sockets.TcpClient]::new()
    $conn = $tcp.BeginConnect($target, $port, $null, $null)
    $ok   = $conn.AsyncWaitHandle.WaitOne($timeout, $false)
    $tcp.Close()
    if ($ok) { Write-Host "  $target`:$port  OPEN"            -ForegroundColor Green }
    else     { Write-Host "  $target`:$port  CLOSED/FILTERED" -ForegroundColor Red   }
}

function iface {
    Get-NetAdapter | Where-Object Status -eq 'Up' | ForEach-Object {
        $ip = (Get-NetIPAddress -InterfaceAlias $_.Name -AddressFamily IPv4 -EA SilentlyContinue).IPAddress
        $gw = (Get-NetRoute    -InterfaceAlias $_.Name -DestinationPrefix '0.0.0.0/0' -EA SilentlyContinue).NextHop
        Write-Host ""
        Write-Host "  $($_.Name)" -ForegroundColor Cyan
        Write-Host "  MAC   : $($_.MacAddress)"
        Write-Host "  IP    : $ip"
        Write-Host "  GW    : $gw"
        Write-Host "  Speed : $([math]::Round($_.LinkSpeed/1MB,0)) Mbps"
    }
    Write-Host ""
}

function arp-table {
    Get-NetNeighbor -EA SilentlyContinue |
        Where-Object { $_.State -ne 'Unreachable' -and $_.IPAddress -notmatch '^ff|^224|^fe80' } |
        Select-Object InterfaceAlias, IPAddress, LinkLayerAddress, State |
        Sort-Object InterfaceAlias, IPAddress | Format-Table -AutoSize
}

function shares {
    Get-SmbShare | Select-Object Name, Path, Description, CurrentUsers | Format-Table -AutoSize
}

function who {
    $s = query user 2>$null
    if ($s) { $s | ForEach-Object { Write-Host $_ } }
    else    { Write-Host "  No active sessions." -ForegroundColor DarkGray }
}

function last-logons {
    param([int]$n = 15)
    Get-WinEvent -LogName Security -MaxEvents 2000 -EA SilentlyContinue |
        Where-Object { $_.Id -eq 4624 -and $_.Properties[8].Value -in 2,10,11 } |
        Select-Object -First $n |
        Select-Object TimeCreated,
            @{N='User';  E={ $_.Properties[5].Value }},
            @{N='Type';  E={ switch($_.Properties[8].Value){2{'Interactive'};10{'Remote'};11{'Cached'}} }},
            @{N='From';  E={ $_.Properties[18].Value }} |
        Format-Table -AutoSize
}

function schtasks-list {
    param([string]$filter = '')
    $t = Get-ScheduledTask | Where-Object State -ne 'Disabled'
    if ($filter) { $t = $t | Where-Object { $_.TaskName -like "*$filter*" } }
    $t | Select-Object TaskName,
        @{N='State';   E={ $_.State }},
        @{N='LastRun'; E={ ($_ | Get-ScheduledTaskInfo -EA SilentlyContinue).LastRunTime }} |
        Sort-Object State, TaskName | Format-Table -AutoSize
}

function firewall-rules {
    param([string]$filter = '', [ValidateSet('Inbound','Outbound')][string]$dir = 'Inbound')
    $r = Get-NetFirewallRule | Where-Object { $_.Enabled -and $_.Direction -eq $dir }
    if ($filter) { $r = $r | Where-Object { $_.DisplayName -like "*$filter*" } }
    $r | Select-Object DisplayName, Action, Profile |
        Sort-Object Action | Format-Table -AutoSize
}

function proc-tree {
    param([string]$filter = '')
    $all    = Get-CimInstance Win32_Process -EA SilentlyContinue
    $lookup = @{}; $all | ForEach-Object { $lookup[$_.ProcessId] = $_ }
    function _pt($proc, $i = 0) {
        $n = $proc.Name
        if ($filter -and $n -notlike "*$filter*") { return }
        $pre = if ($i -gt 0) { '  ' * $i + 'L ' } else { '  ' }
        Write-Host "$pre$n [$($proc.ProcessId)]" -ForegroundColor $(if ($i -eq 0) {'Cyan'} else {'White'})
        $all | Where-Object { $_.ParentProcessId -eq $proc.ProcessId -and $_.ProcessId -ne $proc.ProcessId } |
            ForEach-Object { _pt $_ ($i + 1) }
    }
    $all | Where-Object { -not $lookup.ContainsKey($_.ParentProcessId) -or $_.ParentProcessId -eq 0 } |
        ForEach-Object { _pt $_ }
}

function watch {
    param([scriptblock]$cmd, [int]$interval = 2)
    try {
        while ($true) {
            Clear-Host
            Write-Host "  [watch] every ${interval}s  —  $(Get-Date -Format 'HH:mm:ss')  (Ctrl+C to stop)" -ForegroundColor DarkGray
            Write-Host ""
            & $cmd
            Start-Sleep $interval
        }
    } catch [System.Management.Automation.PipelineStoppedException] {}
}

# ─── 13. DİZİN PRO ──────────────────────────────────────────────

function tree {
    param([string]$dir = '.', [int]$depth = 3)
    function _tree($path, $indent = 0, $max) {
        if ($indent -gt $max) { return }
        Get-ChildItem $path -EA SilentlyContinue | ForEach-Object {
            $pre = if ($indent -gt 0) { '│   ' * ($indent - 1) + '├── ' } else { '' }
            if ($_.PSIsContainer) {
                Write-Host "$pre$($_.Name)/" -ForegroundColor Blue
                _tree $_.FullName ($indent + 1) $max
            } else {
                $sz = if ($_.Length -gt 1MB) { " ($([math]::Round($_.Length/1MB,1))MB)" } else { '' }
                Write-Host "$pre$($_.Name)$sz" -ForegroundColor DarkGray
            }
        }
    }
    Write-Host $((Resolve-Path $dir).Path) -ForegroundColor Cyan
    _tree $dir 1 $depth
}

function count {
    param([string]$dir = '.', [switch]$r)
    $f = if ($r) { Get-ChildItem $dir -Recurse -File -EA SilentlyContinue }
         else    { Get-ChildItem $dir -File -EA SilentlyContinue }
    $d = if ($r) { Get-ChildItem $dir -Recurse -Directory -EA SilentlyContinue }
         else    { Get-ChildItem $dir -Directory -EA SilentlyContinue }
    $sz = ($f | Measure-Object Length -Sum).Sum
    Write-Host "  Files : $($f.Count)"                                   -ForegroundColor Cyan
    Write-Host "  Dirs  : $($d.Count)"                                   -ForegroundColor Yellow
    Write-Host "  Total : $([math]::Round($sz / 1MB, 2)) MB"             -ForegroundColor Green
}

function find-large {
    param([float]$mb = 100, [string]$dir = '.')
    Get-ChildItem $dir -Recurse -File -EA SilentlyContinue |
        Where-Object { $_.Length -gt ($mb * 1MB) } |
        Sort-Object Length -Descending |
        Select-Object @{N='Size(MB)';E={[math]::Round($_.Length/1MB,1)}}, FullName |
        Format-Table -AutoSize
}

function find-old {
    param([int]$days = 30, [string]$dir = '.')
    $cut = (Get-Date).AddDays(-$days)
    Get-ChildItem $dir -Recurse -File -EA SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cut } |
        Sort-Object LastWriteTime |
        Select-Object LastWriteTime, @{N='Size(MB)';E={[math]::Round($_.Length/1MB,2)}}, FullName |
        Format-Table -AutoSize
}

function ls-size {
    param([string]$dir = '.')
    Get-ChildItem $dir -EA SilentlyContinue |
        Select-Object Mode, LastWriteTime,
            @{N='Size';E={ if ($_.PSIsContainer) {'<DIR>'} else {"$([math]::Round($_.Length/1KB,1)) KB"} }},
            Name |
        Sort-Object { if ($_.Mode -match 'd') { 0 } else { 1 } }, Name |
        Format-Table -AutoSize
}

# ─── 14. HIZLI ARAÇLAR ──────────────────────────────────────────
function resmon   { Start-Process resmon.exe }
function perfmon  { Start-Process perfmon.exe }
function svcmgr   { Start-Process services.msc }
function diskmgmt { Start-Process diskmgmt.msc }
function taskschd { Start-Process taskschd.msc }
function devmgmt  { Start-Process devmgmt.msc }
function eventlog { Start-Process eventvwr.msc }
function msinfo   { Start-Process msinfo32.exe }
function sfc-scan {
    Start-Process pwsh -Verb RunAs -ArgumentList '-NoExit -Command "sfc /scannow"'
}
function dism-check {
    Start-Process pwsh -Verb RunAs -ArgumentList '-NoExit -Command "DISM /Online /Cleanup-Image /CheckHealth"'
}

# ─── 15. COMPLETIONS ───────────────────────────────────────────

# Set-Theme → C:\dotFiles\PoshThemes altındaki tema adları
Register-ArgumentCompleter -CommandName Set-Theme -ParameterName name -ScriptBlock {
    param($cmd, $param, $word)
    Get-ChildItem 'C:\dotFiles\PoshThemes\*.omp.json' -EA SilentlyContinue |
        ForEach-Object { $_.Name -replace '\.omp\.json$','' } |
        Where-Object { $_ -like "$word*" } |
        ForEach-Object { [Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
}

# kill-port → dinleyen portlar
Register-ArgumentCompleter -CommandName kill-port -ParameterName port -ScriptBlock {
    param($cmd, $param, $word)
    Get-NetTCPConnection -State Listen -EA SilentlyContinue |
        Select-Object -ExpandProperty LocalPort -Unique | Sort-Object |
        Where-Object { "$_" -like "$word*" } |
        ForEach-Object { [Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
}

# pkill, pgrep → çalışan process isimleri
$_procCompleter = {
    param($cmd, $param, $word)
    Get-Process -EA SilentlyContinue | Select-Object -ExpandProperty Name -Unique | Sort-Object |
        Where-Object { $_ -like "$word*" } |
        ForEach-Object { [Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
}
Register-ArgumentCompleter -CommandName pkill -ParameterName name  -ScriptBlock $_procCompleter
Register-ArgumentCompleter -CommandName pgrep -ParameterName name  -ScriptBlock $_procCompleter

# hash → algoritma adları
Register-ArgumentCompleter -CommandName hash -ParameterName algo -ScriptBlock {
    param($cmd, $param, $word)
    'MD5','SHA1','SHA256','SHA384','SHA512' | Where-Object { $_ -like "$word*" } |
        ForEach-Object { [Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
}

# svcs → servis adları (sadece çalışanlar)
Register-ArgumentCompleter -CommandName svcs -ParameterName filter -ScriptBlock {
    param($cmd, $param, $word)
    Get-Service -EA SilentlyContinue | Where-Object { $_.Status -eq 'Running' -and $_.Name -like "$word*" } |
        ForEach-Object { [Management.Automation.CompletionResult]::new($_.Name, $_.Name, 'ParameterValue', $_.DisplayName) }
}

# wifi-pass → kayıtlı SSID'ler
Register-ArgumentCompleter -CommandName wifi-pass -ParameterName ssid -ScriptBlock {
    param($cmd, $param, $word)
    (netsh wlan show profiles 2>$null) -match 'All User Profile' |
        ForEach-Object { ($_ -split ':')[1].Trim() } |
        Where-Object { $_ -like "$word*" } |
        ForEach-Object { [Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
}

# env-set → mevcut env değişken adları
Register-ArgumentCompleter -CommandName env-set -ParameterName name -ScriptBlock {
    param($cmd, $param, $word)
    Get-ChildItem Env: | Where-Object { $_.Name -like "$word*" } | Sort-Object Name |
        ForEach-Object { [Management.Automation.CompletionResult]::new($_.Name, $_.Name, 'ParameterValue', $_.Value) }
}

# dns-lookup → hosts dosyasındaki girdiler + genel siteler
Register-ArgumentCompleter -CommandName dns-lookup -ParameterName host -ScriptBlock {
    param($cmd, $param, $word)
    $known = @('google.com','github.com','cloudflare.com','8.8.8.8','1.1.1.1')
    $hosts = Get-Content "$env:SystemRoot\System32\drivers\etc\hosts" -EA SilentlyContinue |
        Where-Object { $_ -notmatch '^\s*#' -and $_ -match '\S' } |
        ForEach-Object { ($_ -split '\s+')[1] } | Where-Object { $_ }
    ($known + $hosts) | Select-Object -Unique | Where-Object { $_ -like "$word*" } |
        ForEach-Object { [Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
}

# weather → büyük şehirler
Register-ArgumentCompleter -CommandName weather -ParameterName city -ScriptBlock {
    param($cmd, $param, $word)
    'Istanbul','Ankara','Izmir','Bursa','Antalya','London','Berlin','Paris','NewYork','Tokyo' |
        Where-Object { $_ -like "$word*" } |
        ForEach-Object { [Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
}


# scan-port → hosts dosyasındaki + ARP'taki host'lar
Register-ArgumentCompleter -CommandName scan-port -ParameterName target -ScriptBlock {
    param($cmd, $param, $word)
    $from_hosts = Get-Content "$env:SystemRoot\System32\drivers\etc\hosts" -EA SilentlyContinue |
        Where-Object { $_ -notmatch '^\s*#' -and $_ -match '\S' } |
        ForEach-Object { ($_ -split '\s+')[1] } | Where-Object { $_ }
    $from_arp = (arp -a 2>$null) -match '^\s+\d' |
        ForEach-Object { ($_ -split '\s+')[1] } | Where-Object { $_ }
    ($from_hosts + $from_arp) | Select-Object -Unique |
        Where-Object { $_ -like "$word*" } |
        ForEach-Object { [Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
}

# firewall-rules → direction
Register-ArgumentCompleter -CommandName firewall-rules -ParameterName dir -ScriptBlock {
    param($cmd, $param, $word)
    'Inbound','Outbound' | Where-Object { $_ -like "$word*" } |
        ForEach-Object { [Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
}

# schtasks-list → task isimleri
Register-ArgumentCompleter -CommandName schtasks-list -ParameterName filter -ScriptBlock {
    param($cmd, $param, $word)
    Get-ScheduledTask -EA SilentlyContinue | Where-Object { $_.TaskName -like "$word*" } |
        Select-Object -First 30 |
        ForEach-Object { [Management.Automation.CompletionResult]::new($_.TaskName, $_.TaskName, 'ParameterValue', $_.TaskPath) }
}

# ─── 16. STARTUP ────────────────────────────────────────────────
if ($Host.Name -eq 'ConsoleHost') {
    Clear-Host
    $psVer = "$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"
    $upH   = [math]::Round(((Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime).TotalHours, 1)

    Write-Host ""
    Write-Host "  $env:USERNAME @ $env:COMPUTERNAME" -ForegroundColor White
    Write-Host "  PS $psVer  |  up ${upH}h  |  type 'cmds' for help" -ForegroundColor DarkBlue
    Write-Host ""
}

Remove-Variable _hasPredictor, _zCache, _themePath, _ompCache, _procCompleter -EA SilentlyContinue
