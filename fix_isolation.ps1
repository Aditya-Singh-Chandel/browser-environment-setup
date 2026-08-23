param(
    [string]$VmxPath = ""
)

if (-not $VmxPath) {
    $searchRoots = @(
        "$env:USERPROFILE\Documents\Virtual Machines",
        "$env:USERPROFILE\OneDrive\Documents\Virtual Machines",
        "$env:PUBLIC\Documents\Virtual Machines"
    )
    $found = @()
    foreach ($root in $searchRoots) {
        if (Test-Path $root) {
            $found += Get-ChildItem -Path $root -Filter "*.vmx" -Recurse -ErrorAction SilentlyContinue
        }
    }

    if ($found.Count -eq 1) {
        $VmxPath = $found[0].FullName
    } elseif ($found.Count -gt 1) {
        $VmxPath = $found[0].FullName
    } else {
        Write-Host "Please specify -VmxPath <path-to-.vmx>"
        exit 1
    }
}
$content = Get-Content $VmxPath -Raw

# Enable copy/paste between host and VM
$content = $content -replace 'isolation.tools.copy.disable = "TRUE"', 'isolation.tools.copy.disable = "FALSE"'
$content = $content -replace 'isolation.tools.paste.disable = "TRUE"', 'isolation.tools.paste.disable = "FALSE"'
# Enable drag and drop
$content = $content -replace 'isolation.tools.dnd.disable = "TRUE"', 'isolation.tools.dnd.disable = "FALSE"'
# Enable shared folders (HGFS)
$content = $content -replace 'isolation.tools.hgfs.disable = "TRUE"', 'isolation.tools.hgfs.disable = "FALSE"'

[System.IO.File]::WriteAllText($vmxPath, $content, (New-Object System.Text.UTF8Encoding $false))
Write-Host "Done! Copy/paste, drag-drop, shared folders all enabled."
Write-Host "Restart VM for changes to take effect."
