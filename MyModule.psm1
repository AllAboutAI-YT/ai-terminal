# Load required modules
Import-Module -Name PSReadLine
Import-Module -Name PSOpenAI

# Set OpenAI API key
$env:OPENAI_API_KEY = "APIKEY"

# Define cache file path
$cacheFile = Join-Path $PSScriptRoot "cache.json"

# Load cache from file
function Load-Cache {
    if (Test-Path $cacheFile) {
        return Get-Content $cacheFile | ConvertFrom-Json
    }
    return @{}
}

# Save cache to file
function Save-Cache($cache) {
    $cache | ConvertTo-Json | Set-Content $cacheFile
}

# Scan local files and directories
function Scan-LocalFiles($directory) {
    return Get-ChildItem -Path $directory -Recurse -File | Select-Object -ExpandProperty FullName
}

# Get OpenAI suggestion
function Get-OpenAISuggestion($query) {
    $systemMessage = "You are a expert in Powershell and terminal commands, and general software development. Keep your responses on point and non-verbose"
    $temperature = 0.5
    $response = Request-ChatCompletion -Message $query -Model "gpt-3.5-turbo" -MaxTokens 200 -SystemMessage $systemMessage -Temperature $temperature
    return $response.Answer
}

# Process command with OpenAI
function Process-CommandWithOpenAI {
    param($command)
    $formattedQuery = "Explain what this command does: $command"
    $answer = Get-OpenAISuggestion -Query $formattedQuery
    Write-Host "`nOpenAI Explains: $answer`n"
}

# Process user input
function Ask-OpenAI {
    param($Question)
    $answer = Get-OpenAISuggestion -Query $Question
    Write-Host "Answer: $answer"
}

# Register custom autocomplete and command processing functions
function AutoComplete {
    param($key, $arg)
    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    $lastWord = $line.Substring(0, $cursor).Split(' ')[-1]
    $cache = Load-Cache
    $fileList = $cache.FileList

    if ($null -eq $fileList) {
        $fileList = Scan-LocalFiles -Directory "."
        $cache.FileList = $fileList
        Save-Cache -Cache $cache
    }

    $suggestions = @()
    if ($lastWord -match "^\.?\.?\\") {
        $suggestions += Get-ChildItem -Path $lastWord -Directory | Select-Object -ExpandProperty Name
        $suggestions += $fileList | Where-Object { $_ -like "$lastWord*" }
    }
    $suggestions += Get-Command -Name "$lastWord*" | Select-Object -ExpandProperty Name
    $openAISuggestions = Get-OpenAISuggestion -Query "Autocomplete: $line"
    $suggestions += $openAISuggestions.Split("`n") | Where-Object { $_ -like "$lastWord*" }

    if ($suggestions.Count -gt 0) {
        $selectedSuggestion = $suggestions | Out-GridView -Title "Autocomplete Suggestions" -OutputMode Single
        if ($selectedSuggestion) {
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert($selectedSuggestion.Substring($lastWord.Length))
        }
    }
}

Set-PSReadLineKeyHandler -Key Ctrl+Spacebar -ScriptBlock $Function:AutoComplete
Set-PSReadLineKeyHandler -Chord Ctrl+Enter -ScriptBlock {
    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    Process-CommandWithOpenAI -command $line
}

# Setup PSReadLine and key handlers
Set-PSReadLineOption -EditMode Windows
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle InlineView

# Setup key handlers for history search
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# Export module members
Export-ModuleMember -Function AutoComplete, Get-OpenAISuggestion, Process-CommandWithOpenAI, Scan-LocalFiles, Load-Cache, Save-Cache, Ask-OpenAI