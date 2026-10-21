Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$Aab = "build/app/outputs/bundle/release/app-release.aab"
$Zip = [System.IO.Compression.ZipFile]::OpenRead(
    (Resolve-Path $Aab).Path
)

try {
    Write-Host "`n=== r8.json ==="

    $Entry = $Zip.GetEntry(
        "BUNDLE-METADATA/com.android.tools/r8.json"
    )

    if ($Entry) {
        $Reader = [System.IO.StreamReader]::new($Entry.Open())
        try {
            $Json = $Reader.ReadToEnd() | ConvertFrom-Json
            $Json | ConvertTo-Json -Depth 10
        }
        finally {
            $Reader.Dispose()
        }
    }
    else {
        Write-Host "r8.json not found."
    }

    Write-Host "`n=== DEX files ==="

    $DexFiles = @(
        $Zip.Entries | Where-Object {
            $_.FullName -match '\.dex$'
        }
    )

    $TotalBytes = ($DexFiles | Measure-Object -Property Length -Sum).Sum

    if ($null -eq $TotalBytes) {
        $TotalBytes = 0
    }

    Write-Host "DEX files found: $($DexFiles.Count)"
    Write-Host "Total uncompressed DEX size: $TotalBytes bytes"
    Write-Host ("Total uncompressed DEX size: {0:N2} MiB" -f ($TotalBytes / 1MB))

    $DexFiles | Select-Object FullName, Length | Format-Table -AutoSize
}
finally {
    $Zip.Dispose()
}
