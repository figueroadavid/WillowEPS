function New-WEPSTargetServerMenu {
    <#
        Returns: List[object] of environment objects selected
        Uses: $script:ServerListData.Environments
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Message,

        [string]$QuitText = '&Quit',
        [string]$QuitHelp = 'Exit this menu'
    )

    # Remaining choices are ENVIRONMENT OBJECTS
    $remaining = @($script:ServerListData.Environments | Sort-Object Name)

    $selected = [System.Collections.Generic.List[object]]::new()

    while ($true) {

        if (-not $remaining -or $remaining.Count -eq 0) { break }

        $choices = New-Object System.Collections.Generic.List[System.Management.Automation.Host.ChoiceDescription]
        $lines = New-Object System.Collections.Generic.List[string]

        $used = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        $null = $used.Add('Q') # reserve Q for quit

        for ($i = 0; $i -lt $remaining.Count; $i++) {
            $envObj = $remaining[$i]
            $name = $envObj.Name

            $label = Add-MenuHotkey -Text $name -UsedKeys $used
            $help = "Add servers for environment: $name"

            $choices.Add([System.Management.Automation.Host.ChoiceDescription]::new($label, $help)) | Out-Null
            $lines.Add(('{0,2}. {1}' -f ($i + 1), $name)) | Out-Null
        }

        $quitLabel = Add-MenuHotkey -Text $QuitText -UsedKeys $used
        $choices.Add([System.Management.Automation.Host.ChoiceDescription]::new($quitLabel, $QuitHelp)) | Out-Null

        $display = $Message + [Environment]::NewLine + ($lines -join [Environment]::NewLine)

        $default = $choices.Count - 1
        $idx = $Host.UI.PromptForChoice($Title, $display, $choices.ToArray(), $default)

        # Quit is the last entry
        if ($idx -eq ($choices.Count - 1)) { break }

        $picked = $remaining[$idx]
        $selected.Add($picked) | Out-Null

        # Remove from remaining so it can't be picked twice
        $remaining = @($remaining | Where-Object { $_.Name -ne $picked.Name })
    }

    return $selected
}
