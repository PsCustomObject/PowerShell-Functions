BeforeAll {
    $loaderPath = (Resolve-Path (Join-Path $PSScriptRoot '../New-LogEntry.ps1')).Path
    New-Module -Name StandaloneNewLogEntry -ArgumentList $loaderPath -ScriptBlock {
        param($Loader)
        . $Loader
    } | Import-Module -Force
}
AfterAll { Remove-Module StandaloneNewLogEntry }

Describe 'New-LogEntry audit regressions' {
    BeforeEach {
        New-LogEntry -ClearBuffer
    }

    It 'treats regex replacement expressions as literal text: <Replacement>' -ForEach @(
        @{ Replacement = '$0' }
        @{ Replacement = '$1' }
        @{ Replacement = '$&' }
        @{ Replacement = '$$' }
        @{ Replacement = '${secret}' }
    ) {
        $path = Join-Path $TestDrive ([guid]::NewGuid().ToString() + '.log')
        $line = New-LogEntry -LogMessage 'token=do-not-disclose' -RedactSecrets -RedactionText $Replacement -LogFilePath $path -NoConsole -PassThru
        $line | Should -Not -Match 'do-not-disclose'
        $line.EndsWith($Replacement) | Should -BeTrue
        (Get-Content -LiteralPath $path) | Should -Be $line
        New-LogEntry -LogMessage 'token=do-not-disclose' -BufferOnly -RedactPattern '(?<secret>token=\S+)' -RedactionText $Replacement
        (New-LogEntry -GetBuffer).EndsWith($Replacement) | Should -BeTrue
    }

    It 'rejects conflicting buffered severity switches: <First> and <Second>' -ForEach @(
        @{ First = 'BufferOnlyInfo'; Second = 'BufferOnlyWarning' }
        @{ First = 'BufferOnlyInfo'; Second = 'BufferOnlyError' }
        @{ First = 'BufferOnlyWarning'; Second = 'BufferOnlyError' }
    ) {
        $flags = @{ $First = $true; $Second = $true }
        { New-LogEntry -LogMessage 'conflict' @flags } | Should -Throw '*Use only one*'
        @(New-LogEntry -GetBuffer).Count | Should -Be 0
    }

    It 'still accepts individual buffered severity switches: <Flag>' -ForEach @(
        @{ Flag = 'BufferOnlyInfo'; Tag = 'INFO' }
        @{ Flag = 'BufferOnlyWarning'; Tag = 'WARNING' }
        @{ Flag = 'BufferOnlyError'; Tag = 'ERROR' }
    ) {
        $flags = @{ $Flag = $true }
        New-LogEntry -LogMessage 'message' -BufferOnly @flags
        (New-LogEntry -GetBuffer) | Should -Match "\[$Tag\]: message$"
    }

    It 'preserves an entry appended while the snapshot is being written' {
        InModuleScope StandaloneNewLogEntry {
            Mock Write-NewLogEntryLines {
                [System.Threading.Monitor]::IsEntered($script:NewLogEntryBufferLock) | Should -BeTrue
                Add-NewLogEntryBuffer -Lines 'arrived-during-flush'
            }
            New-LogEntry -LogMessage 'original' -BufferOnly
            $flushed = @(New-LogEntry -FlushBuffer -LogFilePath 'unused.log' -NoConsole -PassThru)
            $flushed.Count | Should -Be 1
            $flushed[0] | Should -Match ': original$'
            @(New-LogEntry -GetBuffer).Count | Should -Be 1
            (New-LogEntry -GetBuffer) | Should -Be 'arrived-during-flush'
            $script:messageBuffer | Should -Be ("arrived-during-flush" + [Environment]::NewLine)
        }
    }

    It 'retains all entries when writing fails and releases the buffer lock' {
        InModuleScope StandaloneNewLogEntry {
            Mock Write-NewLogEntryLines { throw 'write failed' }
            New-LogEntry -LogMessage 'retry-me' -BufferOnly
            { New-LogEntry -FlushBuffer -LogFilePath 'unused.log' -NoConsole } | Should -Throw '*write failed*'
            (New-LogEntry -GetBuffer) | Should -Match ': retry-me$'
            [System.Threading.Monitor]::IsEntered($script:NewLogEntryBufferLock) | Should -BeFalse
            New-LogEntry -LogMessage 'next' -BufferOnly
            @(New-LogEntry -GetBuffer).Count | Should -Be 2
        }
    }

    It 'writes buffered entries exactly once across successive flushes' {
        $path = Join-Path $TestDrive 'once.log'
        New-LogEntry -LogMessage 'once' -BufferOnly
        New-LogEntry -FlushBuffer -LogFilePath $path -NoConsole
        New-LogEntry -FlushBuffer -LogFilePath $path -NoConsole
        @(Get-Content -LiteralPath $path).Count | Should -Be 1
        @(New-LogEntry -GetBuffer).Count | Should -Be 0
    }

    It 'resolves interactive defaults in the current directory' {
        InModuleScope StandaloneNewLogEntry -Parameters @{ Directory = $TestDrive } {
            param($Directory)
            Push-Location $Directory
            try {
                $path = Resolve-NewLogEntryPath
                (Split-Path $path -Parent) | Should -Be $Directory
                (Split-Path $path -Leaf) | Should -Match '^PowerShell-LogFile-\d{8}-\d{6}\.log$'
            }
            finally { Pop-Location }
        }
    }

    It 'writes default logs beside a calling script, including buffer flushes' {
        $scriptDirectory = Join-Path $TestDrive 'caller'
        New-Item -ItemType Directory $scriptDirectory | Out-Null
        $caller = Join-Path $scriptDirectory 'automation.ps1'
        @'
New-LogEntry -LogMessage 'direct-default' -NoConsole
New-LogEntry -LogMessage 'buffer-default' -BufferOnly
New-LogEntry -FlushBuffer -NoConsole
'@ | Set-Content -LiteralPath $caller
        & $caller
        $logs = @(Get-ChildItem $scriptDirectory -Filter 'automation.ps1-LogFile-*.log')
        $logs.Count | Should -BeGreaterThan 0
        $lines = @(Get-Content -LiteralPath $logs.FullName)
        $lines.Count | Should -Be 2
        $lines[0] | Should -Match ': direct-default$'
        $lines[1] | Should -Match ': buffer-default$'
    }
}


Describe 'New-LogEntry file-write integration' {
    BeforeEach { New-LogEntry -ClearBuffer }

    It 'can retry buffered entries after a real filesystem failure' {
        New-LogEntry -LogMessage 'retained-after-failure' -BufferOnly
        { New-LogEntry -FlushBuffer -LogFilePath $TestDrive -NoConsole -ErrorAction Stop } | Should -Throw
        $before = @(New-LogEntry -GetBuffer)
        $before.Count | Should -Be 1
        $path = Join-Path $TestDrive 'retried.log'
        $written = @(New-LogEntry -FlushBuffer -LogFilePath $path -NoConsole -PassThru)
        $written[0] | Should -Be $before[0]
        (Get-Content -LiteralPath $path) | Should -Be $before[0]
        @(New-LogEntry -GetBuffer).Count | Should -Be 0
    }

    It 'preserves every direct and buffered line from concurrent processes' {
        $path = Join-Path $TestDrive 'concurrent.log'
        $manifest = $loaderPath
        $jobs = @()
        try {
            $jobs = @(1..3 | ForEach-Object {
                Start-Job -ArgumentList $manifest, $path, $_ -ScriptBlock {
                    param($Manifest, $Path, $Worker)
                    . $Manifest
                    foreach ($i in 1..20) {
                        New-LogEntry -LogMessage "worker-$Worker-direct-$i" -LogFilePath $Path -NoConsole -ErrorAction Stop
                        New-LogEntry -LogMessage "worker-$Worker-buffer-$i" -BufferOnly -ErrorAction Stop
                    }
                    New-LogEntry -FlushBuffer -LogFilePath $Path -NoConsole -ErrorAction Stop
                }
            })
            $jobs | Receive-Job -Wait -ErrorAction Stop
            foreach ($job in $jobs) { $job.State | Should -Be 'Completed' }
            $lines = @(Get-Content -LiteralPath $path)
            $lines.Count | Should -Be 120
            $messages = @($lines | ForEach-Object { $_ -replace '^.*\[INFO\]: ', '' })
            @($messages | Select-Object -Unique).Count | Should -Be 120
            foreach ($worker in 1..3) {
                foreach ($i in 1..20) {
                    $messages | Should -Contain "worker-$worker-direct-$i"
                    $messages | Should -Contain "worker-$worker-buffer-$i"
                }
            }
        }
        finally {
            if ($jobs.Count -gt 0) { $jobs | Remove-Job -Force }
        }
    }
}


Describe 'Interactive default log path' {
    It 'writes in the current directory when called without a script file' {
        $manifest = $loaderPath
        $job = Start-Job -ArgumentList $manifest, $TestDrive -ScriptBlock {
            param($Manifest, $Directory)
            . $Manifest
            Set-Location $Directory
            New-LogEntry -LogMessage 'interactive-default' -NoConsole -ErrorAction Stop
            New-LogEntry -LogMessage 'interactive-buffer' -BufferOnly
            New-LogEntry -FlushBuffer -NoConsole -ErrorAction Stop
        }
        try {
            $job | Receive-Job -Wait -ErrorAction Stop
            $job.State | Should -Be 'Completed'
            $logs = @(Get-ChildItem $TestDrive -Filter 'PowerShell-LogFile-*.log')
            $logs.Count | Should -BeGreaterThan 0
            $lines = @(Get-Content -LiteralPath $logs.FullName)
            $lines.Count | Should -Be 2
            $lines[0] | Should -Match ': interactive-default$'
            $lines[1] | Should -Match ': interactive-buffer$'
        }
        finally { $job | Remove-Job -Force }
    }
}
