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

    It 'Mentions Python as default' {
        $readme | Should -Match 'Python|pypsirepacker' -Because 'README should mention Python/pypsirepacker'
    }

    It 'Mentions PsiRepacker as legacy' {
        $readme | Should -Match 'PsiRepacker|legacy' -Because 'README should mention legacy PsiRepacker option'
    }

    It 'Documents key parameters' -ForEach @(
        @{ Param = 'Parallelism' }
        @{ Param = 'SkipDownload' }
        @{ Param = 'KeepHashFile' }
        @{ Param = 'UsePsiRepacker' }
        @{ Param = 'PsiRepackerPath' }
        @{ Param = 'UseLegacyPsiRepacker' }
    ) {
        $readme | Should -Match $Param -Because "README should document -$Param"
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
        $license | Should -Match 'BSD.3.Clause' -Because 'LICENSE should include BSD-3-Clause for PyPsiRepacker/PsiRepacker'
    }
}
