function Add-MenuHotkey {
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [Parameter(Mandatory)]
        [System.Collections.Generic.HashSet[string]]$UsedKeys
    )

    $amp = [char]38  # accelerator marker "&" without typing it
    $chars = $Text.ToCharArray()

    for ($i = 0; $i -lt $chars.Length; $i++) {
        $candidate = $chars[$i].ToString()
        if ($candidate -match '\p{L}' ) {
            # letters only; drop this if you want digits/punct too
            if ($UsedKeys.Add($candidate)) {
                # Insert & before the chosen character
                return ($Text.Substring(0, $i) + $amp + $chars[$i] + $Text.Substring($i + 1))
            }
        }
    }
    # No available unique hotkey
    return $Text
}