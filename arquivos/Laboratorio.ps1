#Requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('Install','Connect1','Connect2','Remove')][string]$Action = 'Install')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$exitCode = 0

# Elevacao no proprio Windows. Nenhuma politica permanente e alterada.
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    try {
        $argsText = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -Action {1}' -f $PSCommandPath, $Action
        $process = Start-Process powershell.exe -ArgumentList $argsText -Verb RunAs -PassThru -Wait
        exit $process.ExitCode
    } catch { Write-Host 'E necessario aceitar a permissao de administrador para usar o Hyper-V.'; exit 1 }
}

. "$PSScriptRoot\Funcoes.ps1"
$script:Root = Join-Path $env:ProgramData 'RHCSA-Automatico'
$script:StateFile = Join-Path $script:Root 'estado.json'
$script:AccessFile = Join-Path (Split-Path $PSScriptRoot) 'ACESSOS.html'
$mutex = New-Object Threading.Mutex($false, 'Global\RHCSA-Automatico-v1')
$ownsMutex = $false
try {
    try { $ownsMutex = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $ownsMutex = $true }
    if (-not $ownsMutex) { throw 'Outra janela do laboratorio esta aberta. Termine ou feche aquela janela antes de continuar.' }
    $os = Get-CimInstance Win32_OperatingSystem
    if ($os.ProductType -ne 1) { throw 'Este pacote usa o Default Switch do Windows cliente, nao Windows Server.' }
    if (-not (Get-Module -ListAvailable Hyper-V)) {
        if ($Action -eq 'Remove') { throw 'Hyper-V indisponivel. Remocao bloqueada.' }
        Write-Host 'Habilitando Hyper-V. Isso pode levar alguns minutos...'
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All -NoRestart | Out-Null
        Write-Host 'Salve seu trabalho, reinicie o Windows e abra INICIAR.cmd novamente.'
        return
    }
    Import-Module Hyper-V
    if ((Get-Service vmms).Status -ne 'Running') { throw 'Reinicie o Windows para concluir a ativacao do Hyper-V e execute INICIAR novamente.' }

    if ($Action -eq 'Remove') {
        . "$PSScriptRoot\Remocao.ps1"
        Invoke-RemoveLab
        return
    }
    if ($Action -in @('Connect1','Connect2')) {
        if (-not (Test-Path -LiteralPath $script:StateFile)) { throw 'Execute INICIAR.cmd primeiro.' }
        $script:State = Get-Content -LiteralPath $script:StateFile -Raw | ConvertFrom-Json
        $index = if ($Action -eq 'Connect1') { 0 } else { 1 }
        $entry = $script:State.VMs[$index]
        if ($entry.Stage -ne 'Ready') { throw 'A instalacao ainda nao terminou. Execute INICIAR.cmd.' }
        if (-not (Get-Command ssh.exe -ErrorAction SilentlyContinue)) {
            Write-Host 'Instalando o cliente SSH do Windows...'
            Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0 | Out-Null
        }
        $vm = Get-LabVM $entry
        if ($vm.State -eq 'Off') { Start-VM -VM $vm }
        Write-Host "Aguardando $($entry.Name)..."
        $ip = Wait-LabSSH $entry
        $entry.IP = $ip
        $entry | Add-Member -NotePropertyName IPCheckedAt -NotePropertyValue (Get-Date -Format 'dd/MM/yyyy HH:mm:ss zzz') -Force
        Save-LabState
        Write-AccessTable
        $knownHosts = Join-Path $script:Root "known_hosts_$($entry.Name)"
        [IO.File]::WriteAllText($knownHosts, "$($entry.Name) $($entry.HostKey)`n", [Text.Encoding]::ASCII)
        Write-Host "Acessando $($entry.Name) ($ip). Use a senha escolhida na instalacao."
        # Permite abrir as duas sessoes SSH ao mesmo tempo.
        $mutex.ReleaseMutex(); $ownsMutex = $false
        & ssh.exe -o "UserKnownHostsFile=$knownHosts" -o "HostKeyAlias=$($entry.Name)" -o StrictHostKeyChecking=yes "aluno@$ip"
        if ($LASTEXITCODE -ne 0) { throw 'A conexao SSH foi encerrada com erro. Confira a senha e tente novamente.' }
        return
    }

    $switches = @(Get-VMSwitch | Where-Object { $_.Name -eq 'Default Switch' -or $_.Name -like 'Comutador Padr*' })
    if ($switches.Count -ne 1 -or $switches[0].SwitchType -ne 'Internal') {
        throw 'Default Switch nao encontrado. Reinicie o Windows depois de ativar Hyper-V. Nenhuma rede existente sera removida.'
    }
    $script:State = $null
    if (Test-Path -LiteralPath $script:StateFile) {
        $script:State = Get-Content -LiteralPath $script:StateFile -Raw | ConvertFrom-Json
        if ($script:State.Version -ne 1) { throw 'Registro do laboratorio com versao desconhecida.' }
        if (@($script:State.VMs).Count -ne 2) { throw 'Criacao anterior interrompida antes de preparar as duas VMs. Envie a mensagem ao professor; recursos preservados.' }
        Repair-MissingLabVMs -SwitchName $switches[0].Name -PackageRoot (Split-Path $PSScriptRoot)
        foreach ($entry in $script:State.VMs) { $null = Get-LabVM $entry }
        Write-Host 'Continuando o laboratorio. As VMs existentes foram preservadas.'
    } else {
        $names = @('rhcsa01', 'rhcsa02')
        foreach ($name in $names) {
            if (Get-VM | Where-Object Name -eq $name) { throw "Ja existe uma VM chamada $name de outro roteiro. O professor precisa resolver esse conflito; nada sera substituido." }
        }
        if (Test-Path -LiteralPath $script:Root) { throw "Pasta ja existente sem registro valido: $script:Root. Recursos preservados." }
        $drive = Get-PSDrive -Name ([IO.Path]::GetPathRoot($script:Root).Substring(0,1)) -PSProvider FileSystem
        if ($drive.Free -lt 42GB) { throw 'Libere pelo menos 42 GB no disco do Windows.' }
        $isoFolder = Join-Path (Split-Path $PSScriptRoot) 'pasta da iso'
        $isos = @(Get-ChildItem -LiteralPath $isoFolder -File -Filter '*.iso')
        if ($isos.Count -ne 1) { throw 'Coloque exatamente uma ISO RHEL 10 x86_64 Binary DVD em pasta da iso.' }
        Write-Host 'Conferindo a midia do RHEL...'
        Assert-RhelISO $isos[0].FullName
        $password = Read-LabPassword
        $template = Get-Content -LiteralPath "$PSScriptRoot\instalacao.ks" -Raw
        New-Item -ItemType Directory -Path $script:Root | Out-Null
        # Arquivos temporarios com credenciais acessiveis somente a SYSTEM e administradores.
        $acl = New-Object Security.AccessControl.DirectorySecurity
        $acl.SetAccessRuleProtection($true, $false)
        foreach ($sidText in @('S-1-5-18', 'S-1-5-32-544')) {
            $sid = New-Object Security.Principal.SecurityIdentifier($sidText)
            $rule = New-Object Security.AccessControl.FileSystemAccessRule($sid, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
            $acl.AddAccessRule($rule)
        }
        Set-Acl -LiteralPath $script:Root -AclObject $acl
        $script:State = [pscustomobject]@{ Version = 1; ISO = $isos[0].FullName; VMs = @() }
        Save-LabState
        try {
            foreach ($name in $names) {
                $folder = Join-Path $script:Root $name
                New-Item -ItemType Directory -Path $folder | Out-Null
                $entry = [pscustomobject]@{ Name = $name; Id = ''; Stage = 'Prepared'; Token = [guid]::NewGuid().ToString(); Seed = (Join-Path $folder 'respostas.vhdx'); HostKey = ''; IP = ''; IPCheckedAt = ''; Password = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($password)) }
                New-AnswerDisk $entry $password $template
                $vm = New-VM -Name $name -Generation 2 -MemoryStartupBytes 2GB -Path $folder -NewVHDPath (Join-Path $folder 'sistema.vhdx') -NewVHDSizeBytes 16GB -SwitchName $switches[0].Name
                $entry.Id = $vm.Id.ToString()
                Set-VM -VM $vm -Notes "RHCSA-AUTO-v1:$($entry.Token)" -AutomaticCheckpointsEnabled $false -AutomaticStartAction Nothing -AutomaticStopAction ShutDown
                Set-VMMemory -VM $vm -DynamicMemoryEnabled $false -StartupBytes 2GB
                Set-VMProcessor -VM $vm -Count 2 -CompatibilityForMigrationEnabled $false
                Add-VMHardDiskDrive -VM $vm -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 1 -Path $entry.Seed
                $dvd = Add-VMDvdDrive -VM $vm -ControllerNumber 0 -ControllerLocation 2 -Path $script:State.ISO -Passthru
                Set-VMFirmware -VM $vm -EnableSecureBoot On -SecureBootTemplate MicrosoftUEFICertificateAuthority -FirstBootDevice $dvd
                $script:State.VMs += $entry
                Save-LabState
            }
        } finally { $password = $null }
    }

    # Em uma retomada, nao interromper uma VM em uso sem a escolha do aluno.
    $pendingInstallation = @($script:State.VMs | Where-Object Stage -ne 'Ready').Count -gt 0
    if ($pendingInstallation) {
        foreach ($readyEntry in @($script:State.VMs | Where-Object Stage -eq 'Ready')) {
            if ((Get-LabVM $readyEntry).State -eq 'Running') {
                $answer = Read-Host "Para continuar a instalacao, salvar seu trabalho e desligar $($readyEntry.Name)? Digite S para desligar normalmente"
                if ($answer -ine 'S') { throw 'Instalacao adiada. Desligue a VM com sudo poweroff quando puder e execute INICIAR novamente.' }
                Stop-LabGracefully $readyEntry
            }
        }
    }
    # Instala/verifica uma por vez. As VMs ligadas pelo instalador sao desligadas ao terminar.
    foreach ($entry in $script:State.VMs) {
        if ($pendingInstallation -and $entry.Stage -eq 'Ready') { continue }
        $vm = Get-LabVM $entry
        if ($entry.Stage -eq 'Prepared') {
            if (-not (Test-Path -LiteralPath $script:State.ISO)) { throw 'A ISO foi movida. Devolva-a para pasta da iso no caminho original.' }
            if ($vm.State -eq 'Off') {
                Get-VMDvdDrive -VM $vm | Set-VMDvdDrive -Path $script:State.ISO
                Start-VM -VM $vm
            }
            elseif ($vm.State -ne 'Running') { throw "VM $($entry.Name) em estado inesperado: $($vm.State)." }
            $entry.Stage = 'Installing'; Save-LabState
        }
        if ($entry.Stage -eq 'Installing') {
            Wait-Installed $entry
            $entry.HostKey = Read-InstallResult $entry
            $entry.Stage = 'Installed'; Save-LabState
        }
        if ($entry.Stage -eq 'Installed') {
            $vm = Get-LabVM $entry
            if ($vm.State -ne 'Off') { throw 'A VM deve estar desligada para retirar a midia de instalacao.' }
            Get-VMHardDiskDrive -VM $vm | Where-Object Path -eq $entry.Seed | Remove-VMHardDiskDrive
            Get-VMDvdDrive -VM $vm | Set-VMDvdDrive -Path $null
            $osDisk = @(Get-VMHardDiskDrive -VM $vm)
            if ($osDisk.Count -ne 1) { throw 'Quantidade de discos inesperada apos a instalacao.' }
            Set-VMFirmware -VM $vm -FirstBootDevice $osDisk[0]
            # Exclusao pontual apenas do disco de respostas criado por este pacote.
            if (Test-Path -LiteralPath $entry.Seed) { Remove-Item -LiteralPath $entry.Seed -Force }
            $entry.Stage = 'Booting'; Save-LabState
        }
        if ($entry.Stage -in @('Booting', 'Ready')) {
            $newInstallation = $entry.Stage -eq 'Booting'
            $vm = Get-LabVM $entry
            $startedForCheck = $vm.State -eq 'Off'
            if ($startedForCheck) { Start-VM -VM $vm }
            Write-Host "Verificando acesso do Windows a $($entry.Name)..."
            $entry.IP = Wait-LabSSH $entry
            $entry | Add-Member -NotePropertyName IPCheckedAt -NotePropertyValue (Get-Date -Format 'dd/MM/yyyy HH:mm:ss zzz') -Force
            $entry.Stage = 'Ready'; Save-LabState
            Write-AccessTable
            Write-Host "$($entry.Name) pronta: ssh aluno@$($entry.IP)"
            if ($startedForCheck -or $newInstallation) { Stop-LabGracefully $entry }
        } else { throw "Etapa desconhecida: $($entry.Stage)" }
    }
    Write-Host ''
    Write-Host 'PRONTO! Use ACESSAR MAQUINA 1.cmd ou ACESSAR MAQUINA 2.cmd.' -ForegroundColor Green
    Write-Host 'As VMs iniciadas pelo instalador foram desligadas para economizar RAM. Os atalhos de acesso ligam cada uma.'
    Write-Host 'Usuario: aluno. Senha: a que voce escolheu. Rede NAT com acesso pelo Windows.'
    Write-Host "Tabela com nome, IP, usuario e senha: $script:AccessFile"
} catch {
    $exitCode = 1
    Write-Host "Nao foi possivel concluir: $($_.Exception.Message)" -ForegroundColor Red
    if ($Action -eq 'Remove') {
        Write-Host 'A rotina parou. VMs ja removidas nao sao restauradas; as restantes e os discos foram preservados.'
    } else { Write-Host 'Envie esta mensagem ao professor. As VMs e os discos existentes foram preservados.' }
} finally {
    if ($ownsMutex) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
    Read-Host 'Pressione Enter para fechar' | Out-Null
}
exit $exitCode
