#Requires -Version 5.1
#Requires -Module Pester

<#
.SYNOPSIS
    Documentation validation tests for HIBPBinCreator.
#>

BeforeAll {
    $ProjectRoot = Split-Path $PSScriptRoot -Parent
}

Describe 'Documentation pages exist with content' {
    It '<Page> exists and has content' -ForEach @(
        @{ Page = 'README.md' }
        @{ Page = 'docs/Home.md' }
        @{ Page = 'docs/Architecture.md' }
        @{ Page = 'docs/Operations.md' }
        @{ Page = 'docs/Troubleshooting.md' }
    ) {
        $path = Join-Path $ProjectRoot $Page
        Test-Path $path | Should -BeTrue -Because "$Page should exist"
        (Get-Content $path -Raw).Length | Should -BeGreaterThan 100 -Because "$Page should have meaningful content"
    }
}

Describe 'README content coverage' {
    BeforeAll {
        $readme = Get-Content (Join-Path $ProjectRoot 'README.md') -Raw
    }

    It 'Mentions pypsirepacker' {
        $readme | Should -Match 'pypsirepacker' -Because 'README should mention pypsirepacker'
    }

    It 'Mentions EnableAutoInstall' {
        $readme | Should -Match 'EnableAutoInstall' -Because 'README should mention -EnableAutoInstall'
    }

    It 'Links to documentation pages' -ForEach @(
        @{ Page = 'Architecture' }
        @{ Page = 'Operations' }
        @{ Page = 'Troubleshooting' }
    ) {
        $readme | Should -Match $Page -Because "README should link to $Page"
    }
}

Describe 'Operations documents all parameters' {
    BeforeAll {
        $ops = Get-Content (Join-Path $ProjectRoot 'docs/Operations.md') -Raw
    }

    It 'Documents <Param>' -ForEach @(
        @{ Param = 'EnableAutoInstall' }
        @{ Param = 'OutputPath' }
        @{ Param = 'Parallelism' }
        @{ Param = 'SkipDownload' }
        @{ Param = 'KeepHashFile' }
        @{ Param = 'Repacker' }
        @{ Param = 'settings\.json' }
    ) {
        $ops | Should -Match $Param -Because "Operations should document $Param"
    }
}

Describe 'Settings template' {
    It 'settings.json.example exists and is valid JSON' {
        $examplePath = Join-Path $ProjectRoot 'settings.json.example'
        Test-Path $examplePath | Should -BeTrue -Because 'settings.json.example should exist'
        $content = Get-Content $examplePath -Raw
        { $content | ConvertFrom-Json } | Should -Not -Throw -Because 'settings.json.example should be valid JSON'
    }

    It 'settings.json.example contains expected keys' {
        $examplePath = Join-Path $ProjectRoot 'settings.json.example'
        $parsed = Get-Content $examplePath -Raw | ConvertFrom-Json
        $parsed.PSObject.Properties.Name | Should -Contain 'OutputPath'
        $parsed.PSObject.Properties.Name | Should -Contain 'Parallelism'
        $parsed.PSObject.Properties.Name | Should -Contain 'KeepHashFile'
    }
}

Describe 'Diagram files' {
    It 'HIBP-Pipeline.drawio exists' {
        Test-Path (Join-Path $ProjectRoot 'docs/diagrams/HIBP-Pipeline.drawio') | Should -BeTrue
    }

    It 'HIBP-Pipeline.png exists' {
        Test-Path (Join-Path $ProjectRoot 'docs/diagrams/HIBP-Pipeline.png') | Should -BeTrue
    }
}

Describe 'LICENSE mentions BSD-3-Clause' {
    BeforeAll {
        $license = Get-Content (Join-Path $ProjectRoot 'LICENSE') -Raw
    }

    It 'Contains MIT license text' {
        $license | Should -Match 'MIT' -Because 'LICENSE should include MIT for project scripts'
    }

    It 'Contains BSD-3-Clause attribution' {
        $license | Should -Match 'BSD.3.Clause' -Because 'LICENSE should include BSD-3-Clause for pypsirepacker'
    }
}
