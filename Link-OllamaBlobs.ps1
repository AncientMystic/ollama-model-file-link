<#
.SYNOPSIS
    Replaces duplicate GGUF blobs in Ollama's storage with symbolic links
    pointing to original files in a source directory.
.DESCRIPTION
    Scans a source folder (recursively) for .gguf files, computes their SHA256,
    and looks for matching blobs in the Ollama models directory. If a match is found,
    the blob is deleted and replaced with a symlink to the source file.
.NOTES
    - Must be run as Administrator.
    - Stop Ollama before running.
    - Back up your Ollama models directory first.
#>

# --- CONFIGURATION ---
$sourceRoot = "B:\models"                      # Your original .gguf files directory
$ollamaBlobs = "$env:USERPROFILE\.ollama\models\blobs"  # Ollama blob storage
$ollamaBlobsPrefix = "sha256-"                 # Ollama blob filename prefix

# --- FUNCTIONS ---
function Get-SHA256Hash($filePath) {
    $stream = [System.IO.File]::OpenRead($filePath)
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $hasher.ComputeHash($stream)
    $stream.Close()
    return [BitConverter]::ToString($hashBytes) -replace '-', ''  # Uppercase hex
}

# --- MAIN ---
Write-Host "Stopping Ollama must be done manually. Ensure it's not running. Press Enter to continue..."
Read-Host

$sourceFiles = Get-ChildItem -Path $sourceRoot -Recurse -Filter "*.gguf" -File
$blobList = Get-ChildItem -Path $ollamaBlobs -File | Where-Object { $_.Name -like "$ollamaBlobsPrefix*" }
$blobHashDict = @{}
foreach ($blob in $blobList) {
    # Extract the hash from the filename (after the prefix)
    $hashHex = $blob.Name.Substring($ollamaBlobsPrefix.Length).ToUpper()
    $blobHashDict[$hashHex] = $blob.FullName
}

$linkedCount = 0
$skippedCount = 0
$errorCount = 0

foreach ($source in $sourceFiles) {
    $sourceHash = Get-SHA256Hash $source.FullName
    Write-Host "`nProcessing: $($source.FullName)"
    Write-Host "  SHA256: $sourceHash"

    if ($blobHashDict.ContainsKey($sourceHash)) {
        $blobPath = $blobHashDict[$sourceHash]
        Write-Host "  Match found in blob: $blobPath"

        # Check if the blob is already a symlink
        if ((Get-Item $blobPath).Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            Write-Host "  SKIPPED: Blob is already a symbolic link." -ForegroundColor Yellow
            $skippedCount++
            continue
        }

        # Optional: verify the blob matches (by hash) to be extra safe
        $blobHash = Get-SHA256Hash $blobPath
        if ($blobHash -ne $sourceHash) {
            Write-Host "  WARNING: Blob hash mismatch, skipping." -ForegroundColor Red
            $errorCount++
            continue
        }

        try {
            # Delete the physical blob file
            Remove-Item -Path $blobPath -Force
            # Create symbolic link from blob location to original source
            New-Item -ItemType SymbolicLink -Path $blobPath -Target $source.FullName -Force | Out-Null
            Write-Host "  SUCCESS: Blob replaced with symlink." -ForegroundColor Green
            $linkedCount++
        }
        catch {
            Write-Host "  ERROR: $_" -ForegroundColor Red
            $errorCount++
        }
    }
    else {
        Write-Host "  No matching blob found. The model may not be imported in Ollama yet." -ForegroundColor Gray
        $skippedCount++
    }
}

Write-Host "`n=== Summary ==="
Write-Host "Symbolic links created: $linkedCount"
Write-Host "Skipped: $skippedCount"
Write-Host "Errors: $errorCount"
Write-Host "Remember to restart Ollama when done."