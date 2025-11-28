$ErrorActionPreference = "Stop"

$ConfigPath = if ($env:JEATUNNEL_CONFIG) { $env:JEATUNNEL_CONFIG } else { Join-Path $env:USERPROFILE ".jeatunnel.json" }
$DefaultBaseUrl = if ($env:JEATUNNEL_SERVER) { $env:JEATUNNEL_SERVER } else { "http://127.0.0.1:8000" }

function New-DefaultConfig {
    return [pscustomobject]@{
        base_url = $DefaultBaseUrl
        token    = $null
        user_id  = $null
        username = $null
        plan     = $null
        share_url = $null
    }
}

function Load-Config {
    if (Test-Path $ConfigPath) {
        try { return Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json }
        catch { }
    }
    return New-DefaultConfig
}

function Save-Config($cfg) {
    $cfg | ConvertTo-Json -Depth 5 | Set-Content -Path $ConfigPath -Encoding UTF8
}

function Invoke-Api($cfg, $method, $path, $body) {
    $headers = @{
        "Content-Type" = "application/json"
    }
    if ($cfg.token) { $headers["Authorization"] = "Bearer $($cfg.token)" }
    $uri = ($cfg.base_url.TrimEnd("/")) + $path
    $json = $null
    if ($body) { $json = ($body | ConvertTo-Json -Depth 6) }

    try {
        if ($method -eq "GET") {
            return Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -Body $json -TimeoutSec 20
        } else {
            return Invoke-RestMethod -Method $method -Uri $uri -Headers $headers -Body $json -TimeoutSec 20
        }
    } catch {
        $msg = $_.Exception.Message
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
            try {
                $err = $_.ErrorDetails.Message | ConvertFrom-Json
                if ($err.detail) { $msg = $err.detail }
                elseif ($err.error) { $msg = $err.error }
            } catch { }
        }
        throw "Hata: $msg"
    }
}

function Prompt-Password($label) {
    Write-Host -NoNewline $label
    return Read-Host -AsSecureString | ConvertFrom-SecureString -AsPlainText
}

function Do-Register($cfg, $args) {
    $username = $args.username
    $password = $args.password
    $plan = $args.plan
    if (-not $username) { $username = Read-Host "Kullanıcı adı" }
    if (-not $password) { $password = Prompt-Password "Şifre: " }
    if (-not $plan) { $plan = Read-Host "Plan (premium/elite/premium_plus/founder) [premium]" ; if (-not $plan) { $plan = "premium" } }

    $res = Invoke-Api $cfg "POST" "/register" @{ username=$username; password=$password; plan=$plan }
    $cfg.token = $res.token
    $cfg.user_id = $res.user_id
    $cfg.username = $res.username
    $cfg.plan = $res.plan
    $cfg.share_url = $res.share_url
    Save-Config $cfg
    Write-Host "Giriş yapıldı. UID: $($cfg.user_id) | Plan: $($cfg.plan)"
    Write-Host "Paylaşılacak VPS linki: $($cfg.share_url)"
}

function Do-Login($cfg, $args) {
    $username = $args.username
    $password = $args.password
    if (-not $username) { $username = Read-Host "Kullanıcı adı" }
    if (-not $password) { $password = Prompt-Password "Şifre: " }

    $res = Invoke-Api $cfg "POST" "/login" @{ username=$username; password=$password }
    $cfg.token = $res.token
    $cfg.user_id = $res.user_id
    $cfg.username = $res.username
    $cfg.plan = $res.plan
    $cfg.share_url = $res.share_url
    Save-Config $cfg
    Write-Host "Giriş başarılı. UID: $($cfg.user_id)"
    Write-Host "Paylaşılacak VPS linki: $($cfg.share_url)"
}

function Do-Run($cfg, $args) {
    if (-not $cfg.token) { throw "Önce giriş yapmalısın." }
    $port = $args.port
    if (-not $port) { $port = Read-Host "Tünellenecek port" }
    $res = Invoke-Api $cfg "POST" "/tunnel/start" @{ port=[int]$port }
    Write-Host "Tünel durum: $($res.status) | Port: $($res.port)"
    if ($res.share_url) { Write-Host "Paylaşılacak VPS linki: $($res.share_url)" }
}

function Do-Stop($cfg) {
    if (-not $cfg.token) { throw "Önce giriş yapmalısın." }
    $res = Invoke-Api $cfg "POST" "/tunnel/stop" @{}
    Write-Host "Tünel durduruldu. Toplam istek: $($res.request_count)"
}

function Do-Status($cfg) {
    if (-not $cfg.token) { throw "Önce giriş yapmalısın." }
    $res = Invoke-Api $cfg "GET" "/tunnel/status" $null
    Write-Host "Durum: $($res.status) | Port: $($res.port)"
    Write-Host "İstek sayısı: $($res.request_count) | Plan: $($res.plan)"
    if ($res.last_error) { Write-Host "Son hata: $($res.last_error)" }
    if ($res.share_url) { Write-Host "Paylaşılacak VPS linki: $($res.share_url)" }
}

function Do-Whoami($cfg) {
    if (-not $cfg.user_id) { Write-Host "Kayıtlı oturum yok."; return }
    Write-Host "Kullanıcı: $($cfg.username) | UID: $($cfg.user_id) | Plan: $($cfg.plan)"
    if ($cfg.share_url) { Write-Host "Paylaşılacak VPS linki: $($cfg.share_url)" }
    Write-Host "Sunucu: $($cfg.base_url)"
}

function Do-Config($cfg, $args) {
    if ($args.server) {
        $cfg.base_url = $args.server
        Save-Config $cfg
        Write-Host "Sunucu adresi kaydedildi: $($cfg.base_url)"
    } else {
        Write-Host "Şu anki sunucu: $($cfg.base_url)"
    }
}

function Interactive-Menu($cfg) {
    while ($true) {
        Write-Host ""
        Write-Host "JeaTunnel Menü"
        Write-Host " 1) Kayıt ol"
        Write-Host " 2) Giriş yap"
        Write-Host " 3) Tünel başlat"
        Write-Host " 4) Tünel durdur"
        Write-Host " 5) Durumu göster"
        Write-Host " 6) Oturum bilgisi"
        Write-Host " 0) Çık"
        $choice = Read-Host "Seçim"
        try {
            switch ($choice) {
                "1" { Do-Register $cfg @{} }
                "2" { Do-Login $cfg @{} }
                "3" { Do-Run $cfg @{} }
                "4" { Do-Stop $cfg }
                "5" { Do-Status $cfg }
                "6" { Do-Whoami $cfg }
                "0" { exit 0 }
                default { Write-Host "Geçersiz seçim." }
            }
        } catch {
            Write-Host $_ -ForegroundColor Red
        }
    }
}

function Show-Usage {
@"
Kullanım: aether.ps1 <komut> [parametreler]
Komutlar:
  register [--username u --password p --plan pl]
  login [--username u --password p]
  run [port]
  stop
  status
  whoami
  config [--server URL]
"@
}

# ------------------- Giriş -------------------
$cfg = Load-Config
if (-not (Test-Path $ConfigPath)) { Save-Config $cfg }

if ($args.Count -eq 0) {
    Interactive-Menu $cfg
    exit 0
}

$cmd = $args[0]
$rest = $args[1..($args.Count-1)]

try {
    switch ($cmd) {
        "register" {
            $parsed = @{
                username = $null; password = $null; plan = $null
            }
            for ($i=0; $i -lt $rest.Count; $i+=2) {
                switch ($rest[$i]) {
                    "--username" { $parsed.username = $rest[$i+1] }
                    "--password" { $parsed.password = $rest[$i+1] }
                    "--plan" { $parsed.plan = $rest[$i+1] }
                }
            }
            Do-Register $cfg $parsed
        }
        "login" {
            $parsed = @{
                username = $null; password = $null
            }
            for ($i=0; $i -lt $rest.Count; $i+=2) {
                switch ($rest[$i]) {
                    "--username" { $parsed.username = $rest[$i+1] }
                    "--password" { $parsed.password = $rest[$i+1] }
                }
            }
            Do-Login $cfg $parsed
        }
        "run" {
            $parsed = @{ port = $null }
            if ($rest.Count -ge 1) { $parsed.port = $rest[0] }
            Do-Run $cfg $parsed
        }
        "stop" { Do-Stop $cfg }
        "status" { Do-Status $cfg }
        "whoami" { Do-Whoami $cfg }
        "config" {
            $parsed = @{ server = $null }
            for ($i=0; $i -lt $rest.Count; $i+=2) {
                switch ($rest[$i]) { "--server" { $parsed.server = $rest[$i+1] } }
            }
            Do-Config $cfg $parsed
        }
        default { Show-Usage }
    }
} catch {
    Write-Host $_ -ForegroundColor Red
    exit 1
}
