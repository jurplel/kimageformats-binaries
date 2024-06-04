param(
  $dir
)

function GetDeps($dllPath) {
    # Run dumpbin with /DEPENDENTS option
    $output = & dumpbin.exe /NOLOGO /DEPENDENTS $dllPath

    # Directory of the input DLL
    $inputDir = Split-Path -Path $dllPath

    # Parse the output and filter existing DLLs in the same directory as the input DLL
    $dependencies = $output |
        Where-Object { $_ -match '^\s+.+\.dll$' } |
        ForEach-Object {
            $dllName = $_.Trim()
            $fullDllPath = Join-Path -Path $inputDir -ChildPath $dllName
            if (Test-Path $fullDllPath) {
                $dllName
            }
        }

    return $dependencies
}

function GetNestedDeps($dllPath) {
    $visited = [System.Collections.Generic.HashSet[string]]::new()
    $queue = [System.Collections.Generic.Queue[string]]::new()

    [void]$visited.Add($dllPath)
    $queue.Enqueue($dllPath)

    while ($queue.Count -gt 0) {
        $currentDll = $queue.Dequeue()
        $deps = GetDeps $currentDll

        foreach ($dep in $deps) {
            $fullDepPath = Join-Path (Split-Path $currentDll) $dep
            if (-not $visited.Contains($fullDepPath)) {
                [void]$visited.Add($fullDepPath)
                $queue.Enqueue($fullDepPath)
            }
        }
    }

    # Return all collected dependencies, excluding the initial input
    return $visited | Where-Object { $_ -ne $dllPath } | ForEach-Object { Split-Path $_ -Leaf } | Sort-Object
}

# Loop through DLL files starting with "kimg_" in the specified directory in alphabetical order
Get-ChildItem -Path $dir -Filter "kimg_*.dll" |
    Sort-Object Name |
    ForEach-Object {
        $dllName = $_.Name
        $deps = GetNestedDeps $_.FullName
        
        # Check if any dependencies were found and output appropriately
        if ($deps.Count -gt 0) {
            # Joining dependency names to pass as an array
            $depList = $deps -join '", "'
            Write-Output "$dllName`: `"$depList`""
        }
    }
