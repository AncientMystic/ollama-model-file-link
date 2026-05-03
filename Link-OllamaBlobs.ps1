<#
.SYNOPSIS
    Replaces duplicate GGUF blobs with symlinks, using a hash cache.
    Guaranteed ASCII-only to avoid copy-paste errors.
.NOTES
    Run as Administrator. Stop Ollama first.
#>

$sourceRoot = "B:\models"
$ollamaBlobs = "$env:USERPROFILE\.ollama\models\blobs"
$ollamaBlobsPrefix = "sha256-"

# Cache file location
if ($PSScriptRoot) {
    $cacheFile = Join-Path $PSScriptRoot "model_hash_cache.json"
} else {
    $cacheFile = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "model_hash_cache.json"
}
Write-Host "Cache file: $cacheFile"

# --- Functions ---
function Get-SHA256Hash($filePath) {
    $stream = [System.IO.File]::OpenRead($filePath)
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $hasher.ComputeHash($stream)
    $stream.Close()
    return [BitConverter]::ToString($hashBytes) -replace '-', ''
}

function Load-Cache {
    if (Test-Path $cacheFile) {
        try {
            $json = Get-Content -Raw -Path $cacheFile | ConvertFrom-Json -ErrorAction Stop
            $cache = @{}
            foreach ($prop in $json.PSObject.Properties) {
                $cache[$prop.Name] = @{
                    Hash           = $prop.Value.Hash
                    LastWriteTime  = [datetime]$prop.Value.LastWriteTime
                    Length         = [long]$prop.Value.Length
                }
            }
            Write-Host "Loaded cache with $($cache.Count) entries." -ForegroundColor Cyan
            return $cache
        }
        catch {
            Write-Host "Warning: Could not read cache, ignoring. $_" -ForegroundColor Yellow
        }
    }
    Write-Host "No existing cache found - all files will be hashed."
    return @{}
}

function Save-Cache($cache) {
    Write-Host "Saving cache..." -ForegroundColor DarkCyan
    $output = @{}
    foreach ($key in $cache.Keys) {
        $output[$key] = @{
            Hash          = $cache[$key].Hash
            LastWriteTime = $cache[$key].LastWriteTime.ToString('o')
            Length        = $cache[$key].Length
        }
    }
    try {
        $json = $output | ConvertTo-Json -Depth 5
        Set-Content -Path $cacheFile -Value $json -Force -ErrorAction Stop
        $size = (Get-Item $cacheFile).Length
        Write-Host "Cache saved: $cacheFile ($size bytes, $($cache.Count) entries)" -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR saving cache: $_" -ForegroundColor Red
    }
}

# --- Main ---
Write-Host "`nMake sure Ollama is stopped. Press Enter to continue..."
Read-Host

$hashCache = Load-Cache

$sourceFiles = Get-ChildItem -Path $sourceRoot -Recurse -Filter "*.gguf" -File
$blobList    = Get-ChildItem -Path $ollamaBlobs -File | Where-Object { $_.Name -like "$ollamaBlobsPrefix*" }
$blobHashDict = @{}
foreach ($blob in $blobList) {
    $hashHex = $blob.Name.Substring($ollamaBlobsPrefix.Length).ToUpper()
    $blobHashDict[$hashHex] = $blob.FullName
}

$linkedCount = 0
$skippedCount = 0
$errorCount = 0
$cachedCount = 0

try {
    foreach ($source in $sourceFiles) {
        Write-Host "`nProcessing: $($source.FullName)"
        $currentLength = $source.Length
        $currentLastWrite = $source.LastWriteTimeUtc
        $cacheEntry = $hashCache[$source.FullName]

        if ($cacheEntry -and $cacheEntry.Length -eq $currentLength -and $cacheEntry.LastWriteTime -eq $currentLastWrite) {
            $sourceHash = $cacheEntry.Hash
            Write-Host "  Using cached hash: $sourceHash" -ForegroundColor Cyan
            $cachedCount++
        }
        else {
            Write-Host "  Computing SHA256... (may be slow for large files)"
            $sourceHash = Get-SHA256Hash $source.FullName
            Write-Host "  Computed hash: $sourceHash"
            $hashCache[$source.FullName] = @{
                Hash          = $sourceHash
                LastWriteTime = $currentLastWrite
                Length        = $currentLength
            }
        }

        if ($blobHashDict.ContainsKey($sourceHash)) {
            $blobPath = $blobHashDict[$sourceHash]
            Write-Host "  Match found: $blobPath"

            if ((Get-Item $blobPath).Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                Write-Host "  SKIPPED: Already a symlink." -ForegroundColor Yellow
                $skippedCount++
                continue
            }

            try {
                $blobHash = Get-SHA256Hash $blobPath
                if ($blobHash -ne $sourceHash) {
                    Write-Host "  WARNING: Blob hash mismatch, skipping." -ForegroundColor Red
                    $errorCount++
                    continue
                }
                Remove-Item -Path $blobPath -Force
                New-Item -ItemType SymbolicLink -Path $blobPath -Target $source.FullName -Force | Out-Null
                Write-Host "  SUCCESS: Symlink created." -ForegroundColor Green
                $linkedCount++
            }
            catch {
                Write-Host "  ERROR: $_" -ForegroundColor Red
                $errorCount++
            }
        }
        else {
            Write-Host "  No matching blob found." -ForegroundColor Gray
            $skippedCount++
        }
    }
}
catch {
    Write-Host "FATAL ERROR: $_" -ForegroundColor Red
    $errorCount++
}
finally {
    Save-Cache $hashCache
}

Write-Host "`n=== Summary ==="
Write-Host "Links created : $linkedCount"
Write-Host "Skipped       : $skippedCount"
Write-Host "Errors        : $errorCount"
Write-Host "Cache hits    : $cachedCount (files not re-hashed)"
Write-Host "Start Ollama when done."