$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = (Resolve-Path (Join-Path $ScriptDir "..")).Path
$BinaryPath = Join-Path $ProjectDir "tools\godot-peek-mcp\bin\godot-peek-mcp-windows-amd64.exe"
$SocketEnv = "/tmp/godot-peek-kiem-hiep.sock"

if (-not (Test-Path $BinaryPath)) {
    Write-Error "Binary not found at: $BinaryPath"
    exit 1
}

# Unblock downloaded binary if Windows SmartScreen marked it
Unblock-File -Path $BinaryPath -ErrorAction SilentlyContinue

function Update-McpJsonFile {
    param(
        [string]$FilePath
    )
    $Dir = Split-Path -Parent $FilePath
    if (-not (Test-Path $Dir)) {
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
    }

    $Config = @{}
    if (Test-Path $FilePath) {
        try {
            $Raw = Get-Content -Path $FilePath -Raw -Encoding UTF8
            if ($Raw -and $Raw.Trim().Length -gt 0) {
                $Parsed = $Raw | ConvertFrom-Json -AsHashtable
                if ($Parsed) { $Config = $Parsed }
            }
        } catch {
            # Fallback for PowerShell 5.1 (no -AsHashtable)
            $Obj = Get-Content -Path $FilePath -Raw -Encoding UTF8 | ConvertFrom-Json
            $Config = @{}
            if ($Obj) {
                foreach ($prop in $Obj.PSObject.Properties) {
                    $Config[$prop.Name] = $prop.Value
                }
            }
        }
    }

    if (-not $Config.ContainsKey("mcpServers") -or $null -eq $Config["mcpServers"]) {
        $Config["mcpServers"] = @{}
    } elseif ($Config["mcpServers"] -isnot [hashtable]) {
        $ServersHash = @{}
        foreach ($prop in $Config["mcpServers"].PSObject.Properties) {
            $ServersHash[$prop.Name] = $prop.Value
        }
        $Config["mcpServers"] = $ServersHash
    }

    $Config["mcpServers"]["godot-peek"] = @{
        command = $BinaryPath
        env     = @{
            GODOT_PEEK_SOCKET = $SocketEnv
        }
    }

    $JsonOut = $Config | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($FilePath, $JsonOut, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "[OK] Updated: $FilePath" -ForegroundColor Green
}

Write-Host "=== Setting up Godot Peek MCP for Windows ===" -ForegroundColor Cyan

# 1. Cursor (.cursor/mcp.json)
Update-McpJsonFile -FilePath (Join-Path $ProjectDir ".cursor\mcp.json")

# 2. Claude Code (.mcp.json)
Update-McpJsonFile -FilePath (Join-Path $ProjectDir ".mcp.json")

# 3. Antigravity (%USERPROFILE%\.gemini\config\mcp_config.json)
$AgyConfig = Join-Path $env:USERPROFILE ".gemini\config\mcp_config.json"
Update-McpJsonFile -FilePath $AgyConfig

# 4. Claude Desktop (%APPDATA%\Claude\claude_desktop_config.json)
if ($env:APPDATA) {
    $ClaudeDesktopDir = Join-Path $env:APPDATA "Claude"
    if (Test-Path $ClaudeDesktopDir) {
        Update-McpJsonFile -FilePath (Join-Path $ClaudeDesktopDir "claude_desktop_config.json")
    }
}

Write-Host ""
Write-Host "=== Setup Completed Successfully! ===" -ForegroundColor Cyan
Write-Host "1. Open the project in Godot Editor (plugin is already enabled in project.godot)."
Write-Host "2. Godot will automatically start the local TCP server on 127.0.0.1:6970."
Write-Host "3. Reload MCP servers in Cursor / Antigravity / Claude Code to use godot-peek."

