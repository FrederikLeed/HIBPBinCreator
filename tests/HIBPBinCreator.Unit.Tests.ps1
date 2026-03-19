#Requires -Version 5.1
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for HIBPBinCreator helper functions and script structure.
#>

BeforeAll {
    $ProjectRoot = Split-Path $PSScriptRoot -Parent
    . (Join-Path $ProjectRoot 'lib\HIBPBinCreator.Helpers.ps1')
}

Describe 'Format-Bytes' {
    It 'Formats bytes' {
        Format-Bytes -Bytes 500 | Should -Be '500 B'
    }

    It 'Formats kilobytes' {
        Format-Bytes -Bytes 2048 | Should -Be '2.00 KB'
    }

    It 'Formats megabytes' {
        Format-Bytes -Bytes (5 * 1MB) | Should -Be '5.00 MB'
    }

    It 'Formats gigabytes' {
        Format-Bytes -Bytes (31 * 1GB) | Should -Be '31.00 GB'
    }

    It 'Handles zero' {
        Format-Bytes -Bytes 0 | Should -Be '0 B'
    }
}

Describe 'Format-Elapsed' {
    It 'Formats seconds' {
        Format-Elapsed -ts ([timespan]::FromSeconds(45)) | Should -Be '45s'
    }

    It 'Formats minutes and seconds' {
        Format-Elapsed -ts ([timespan]::FromSeconds(125)) | Should -Be '2m 5s'
    }

    It 'Formats hours' {
        Format-Elapsed -ts ([timespan]::FromHours(2.5)) | Should -Be '2h 30m 0s'
    }
}

Describe 'Test-CommandExists' {
    It 'Returns true for known commands' {
        # PowerShell itself is always available
        Test-CommandExists -Name 'Get-Command' | Should -BeTrue
    }

    It 'Returns false for nonexistent commands' {
        Test-CommandExists -Name 'Not-A-Real-Command-12345' | Should -BeFalse
    }
}

Describe 'Test-PythonAvailable' {
    It 'Returns an object or null' {
        $result = Test-PythonAvailable
        if ($result) {
            $result.ExePath | Should -Not -BeNullOrEmpty
            $result.Version | Should -Match 'Python'
        } else {
            $result | Should -BeNullOrEmpty
        }
    }
}

Describe 'PS 5.1 Syntax Compliance' {
    BeforeAll {
        $ProjectRoot = Split-Path $PSScriptRoot -Parent
        $scripts = Get-ChildItem -Path $ProjectRoot -Filter '*.ps1' -Recurse |
            Where-Object { $_.FullName -notlike '*output*' -and $_.FullName -notlike '*tools*' }
    }

    It 'All .ps1 files parse without errors' {
        foreach ($file in $scripts) {
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$errors) | Out-Null
            $errors | Should -BeNullOrEmpty -Because "$($file.Name) should have no parse errors"
        }
    }

    It 'No null-coalescing operator (??)' {
        foreach ($file in $scripts) {
            $content = Get-Content $file.FullName -Raw
            # Match ?? but not inside strings or comments
            $tokens = $null
            [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$null) | Out-Null
            $hasNullCoalesce = $tokens | Where-Object {
                $_.Kind -eq 'QuestionQuestion'
            }
            $hasNullCoalesce | Should -BeNullOrEmpty -Because "$($file.Name) must not use ?? (PS 7+ only)"
        }
    }

    It 'No ternary operator (? :)' {
        foreach ($file in $scripts) {
            $tokens = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$null)
            $hasTernary = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.TernaryExpressionAst] }, $true)
            $hasTernary | Should -BeNullOrEmpty -Because "$($file.Name) must not use ternary (PS 7+ only)"
        }
    }
}

Describe 'Script Structure' {
    BeforeAll {
        $ProjectRoot = Split-Path $PSScriptRoot -Parent
        $mainScripts = @(
            (Join-Path $ProjectRoot 'PrepareEnv.ps1'),
            (Join-Path $ProjectRoot 'BinaryCreator.ps1')
        )
    }

    It '<Name> has [CmdletBinding()]' -ForEach @(
        @{ Name = 'PrepareEnv.ps1'; Path = (Join-Path (Split-Path $PSScriptRoot -Parent) 'PrepareEnv.ps1') }
        @{ Name = 'BinaryCreator.ps1'; Path = (Join-Path (Split-Path $PSScriptRoot -Parent) 'BinaryCreator.ps1') }
        @{ Name = 'Register-ScheduledTask.ps1'; Path = (Join-Path (Split-Path $PSScriptRoot -Parent) 'Register-ScheduledTask.ps1') }
    ) {
        $content = Get-Content $Path -Raw
        $content | Should -Match '\[CmdletBinding\(\)\]' -Because "$Name should use CmdletBinding"
    }

    It '<Name> has comment-based help' -ForEach @(
        @{ Name = 'PrepareEnv.ps1'; Path = (Join-Path (Split-Path $PSScriptRoot -Parent) 'PrepareEnv.ps1') }
        @{ Name = 'BinaryCreator.ps1'; Path = (Join-Path (Split-Path $PSScriptRoot -Parent) 'BinaryCreator.ps1') }
        @{ Name = 'Register-ScheduledTask.ps1'; Path = (Join-Path (Split-Path $PSScriptRoot -Parent) 'Register-ScheduledTask.ps1') }
    ) {
        $content = Get-Content $Path -Raw
        $content | Should -Match '\.SYNOPSIS' -Because "$Name should have .SYNOPSIS"
        $content | Should -Match '\.DESCRIPTION' -Because "$Name should have .DESCRIPTION"
    }

    It '<Name> has #Requires -Version 5.1' -ForEach @(
        @{ Name = 'PrepareEnv.ps1'; Path = (Join-Path (Split-Path $PSScriptRoot -Parent) 'PrepareEnv.ps1') }
        @{ Name = 'BinaryCreator.ps1'; Path = (Join-Path (Split-Path $PSScriptRoot -Parent) 'BinaryCreator.ps1') }
        @{ Name = 'Register-ScheduledTask.ps1'; Path = (Join-Path (Split-Path $PSScriptRoot -Parent) 'Register-ScheduledTask.ps1') }
        @{ Name = 'HIBPBinCreator.Helpers.ps1'; Path = (Join-Path (Split-Path $PSScriptRoot -Parent) 'lib\HIBPBinCreator.Helpers.ps1') }
    ) {
        $content = Get-Content $Path -Raw
        $content | Should -Match '#Requires -Version 5\.1' -Because "$Name should require PS 5.1"
    }
}
