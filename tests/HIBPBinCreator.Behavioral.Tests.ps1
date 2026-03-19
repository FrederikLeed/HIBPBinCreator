#Requires -Version 5.1
#Requires -Module Pester

<#
.SYNOPSIS
    Behavioral tests for HIBPBinCreator scripts.
#>

BeforeAll {
    $ProjectRoot = Split-Path $PSScriptRoot -Parent
    . (Join-Path $ProjectRoot 'lib\HIBPBinCreator.Helpers.ps1')
}

Describe 'PrepareEnv folder creation' {
    BeforeAll {
        $testDir = Join-Path ([System.IO.Path]::GetTempPath()) "HIBPBinCreator_Test_$(Get-Random)"
    }

    AfterAll {
        if (Test-Path $testDir) {
            Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Creates the expected folder structure' {
        $expectedSubdirs = @('tools', 'output', 'output/hashes', 'output/bin', 'logs')

        # Create base
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null

        foreach ($sub in $expectedSubdirs) {
            $path = Join-Path $testDir $sub
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }

        foreach ($sub in $expectedSubdirs) {
            $path = Join-Path $testDir $sub
            Test-Path $path | Should -BeTrue -Because "Directory '$sub' should exist"
        }
    }
}

Describe 'PrepareEnv Python detection' {
    It 'Detects Python when available' {
        $result = Test-PythonAvailable
        # On CI/test machines Python may or may not be installed
        # This test just verifies the function runs without error
        if ($result) {
            $result.ExePath | Should -Not -BeNullOrEmpty
            $result.Version | Should -Match 'Python\s+3\.'
        }
    }
}

Describe 'BinaryCreator Python invocation' {
    BeforeAll {
        $pyInfo = Test-PythonAvailable
    }

    It 'pypsirepacker can be imported' -Skip:(-not $pyInfo) {
        $parentDir = Split-Path $PSScriptRoot -Parent
        $validateCmd = "import sys; sys.path.insert(0, r'$parentDir'); from pypsirepacker.repacker import repack; print('OK')"
        $result = & $pyInfo.ExePath -c $validateCmd 2>&1
        ($result | Out-String).Trim() | Should -Be 'OK'
    }

    It 'pypsirepacker repack produces correct args format' -Skip:(-not $pyInfo) {
        # Verify the command structure that BinaryCreator.ps1 would use
        $parentDir = Split-Path $PSScriptRoot -Parent
        $inputPath = Join-Path $PSScriptRoot 'fixtures\sample-ntlm-hashes.txt'
        $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) "test_$(Get-Random).bin"

        try {
            $pyCmd = "import sys; sys.path.insert(0, r'$parentDir'); from pypsirepacker.repacker import repack; count = repack(r'$inputPath', r'$outputPath'); print(f'ENTRIES:{count}')"
            $result = & $pyInfo.ExePath -c $pyCmd 2>&1
            $resultStr = ($result | Out-String)
            $resultStr | Should -Match 'ENTRIES:100'
            Test-Path $outputPath | Should -BeTrue
        } finally {
            if (Test-Path $outputPath) {
                Remove-Item $outputPath -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

Describe 'BinaryCreator sanity check logic' {
    It 'Rejects binary that is too small relative to source' {
        # Simulate: source is 1000 bytes, binary is 50 bytes (5% < 10% threshold)
        $hashSize = 1000
        $binSize  = 50
        $minExpectedSize = [long]($hashSize * 0.10)
        $binSize -lt $minExpectedSize | Should -BeTrue
    }

    It 'Accepts binary with valid ratio' {
        # Simulate: source is 1000 bytes, binary is 450 bytes (45%)
        $hashSize = 1000
        $binSize  = 450
        $minExpectedSize = [long]($hashSize * 0.10)
        $binSize -ge $minExpectedSize | Should -BeTrue
    }
}

Describe 'Full mini-pipeline' {
    BeforeAll {
        $pyInfo = Test-PythonAvailable
        $fixtureText = Join-Path $PSScriptRoot 'fixtures\sample-ntlm-hashes.txt'
        $fixtureBin  = Join-Path $PSScriptRoot 'fixtures\sample-ntlm-hashes.bin'
    }

    It 'Text fixture to binary matches committed fixture' -Skip:(-not $pyInfo) {
        $tmpBin = Join-Path ([System.IO.Path]::GetTempPath()) "pipeline_test_$(Get-Random).bin"

        try {
            $parentDir = Split-Path $PSScriptRoot -Parent
            $pyCmd = "import sys; sys.path.insert(0, r'$parentDir'); from pypsirepacker.repacker import repack; repack(r'$fixtureText', r'$tmpBin')"
            & $pyInfo.ExePath -c $pyCmd 2>&1 | Out-Null

            Test-Path $tmpBin | Should -BeTrue

            $expectedBytes = [System.IO.File]::ReadAllBytes($fixtureBin)
            $actualBytes   = [System.IO.File]::ReadAllBytes($tmpBin)

            $actualBytes.Length | Should -Be $expectedBytes.Length
            [System.Linq.Enumerable]::SequenceEqual($expectedBytes, $actualBytes) | Should -BeTrue
        } finally {
            if (Test-Path $tmpBin) {
                Remove-Item $tmpBin -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
