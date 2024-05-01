$modulePath = "C:/Program Files/PowerShell/7/Modules/MyModule/MyModule.psm1"
Import-Module $modulePath

# Ensure PSReadLine and PSOpenAI modules are loaded
Import-Module -Name PSReadLine
Import-Module -Name PSOpenAI

# Custom prompt function to enhance the command line interface
function Prompt {
    Write-Host "(base) PS $($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) " -NoNewline
    return " "
}

# Set this custom prompt
Set-Item -Path Function:Prompt -Value ${Function:Prompt}

# Configure PSReadLine options
Set-PSReadLineOption -EditMode Windows
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle InlineView

# Set up key handlers for efficient command line navigation and history search
Set-PSReadLineKeyHandler -Key Tab -Function AcceptSuggestion
Set-PSReadLineKeyHandler -Chord Ctrl+Spacebar -Function TabCompleteNext
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Chord Ctrl+Enter -ScriptBlock {
    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    Process-CommandWithOpenAI -command $line
}
