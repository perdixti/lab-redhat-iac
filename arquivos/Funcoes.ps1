Set-StrictMode -Version Latest

function Save-LabState {
    $json = $script:State | ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText("$script:StateFile.tmp", $json, [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath "$script:StateFile.tmp" -Destination $script:StateFile -Force
}

function Write-AccessTable {
    $rows = foreach ($entry in $script:State.VMs) {
        $name = [Net.WebUtility]::HtmlEncode([string]$entry.Name)
        $ip = if ($entry.IP) { [Net.WebUtility]::HtmlEncode([string]$entry.IP) } else { 'Aguardando instalacao' }
        $password = if ($entry.PSObject.Properties['Password']) {
            [Net.WebUtility]::HtmlEncode([string]$entry.Password)
        } else { 'Nao registrada pelo pacote anterior' }
        $checked = if ($entry.PSObject.Properties['IPCheckedAt']) {
            [Net.WebUtility]::HtmlEncode([string]$entry.IPCheckedAt)
        } else { 'Ainda nao verificado nesta versao' }
        if ($entry.PSObject.Properties['Stage'] -and $entry.Stage -eq 'Removed') {
            $ip = 'VM removida'; $password = '-'; $checked = '-'
        }
        "<tr><td>$name</td><td>$ip<small>Verificado: $checked</small></td><td>aluno</td><td class='password'>$password</td></tr>"
    }
    $updated = [Net.WebUtility]::HtmlEncode((Get-Date -Format 'dd/MM/yyyy HH:mm:ss zzz'))
    $html = @"
<!doctype html>
<html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Acessos ao laboratorio RHEL</title>
<style>
body{font-family:Segoe UI,Arial,sans-serif;background:#f4f6f8;color:#172033;max-width:1050px;margin:48px auto;padding:0 24px}
h1{font-size:28px}table{width:100%;border-collapse:collapse;background:white;margin:24px 0}
th,td{text-align:left;padding:16px;border-bottom:1px solid #dce2e9}th{background:#172033;color:white}
.password{font-family:Consolas,monospace;white-space:pre-wrap;overflow-wrap:anywhere}small{display:block;color:#586577;font-size:11px;margin-top:6px}
code{background:#e5eaf0;padding:3px 6px}p{line-height:1.6}.note{color:#586577}
</style></head><body>
<h1>Acessos ao laboratorio RHEL</h1>
<p>Rede NAT. Acesse as maquinas pelo Windows deste computador.</p>
<table><thead><tr><th>Nome da VM</th><th>IP</th><th>Usuario</th><th>Senha</th></tr></thead>
<tbody>$($rows -join "`n")</tbody></table>
<p>Use <strong>ACESSAR MAQUINA 1.cmd</strong> ou <strong>ACESSAR MAQUINA 2.cmd</strong>.
Pelo terminal, use <code>ssh aluno@IP</code>, substituindo IP pelo endereco da tabela.</p>
<p class="note">Arquivo atualizado: $updated. Cada IP corresponde a sua ultima verificacao;
o NAT pode atribuir outro IP. Execute INICIAR.cmd para verificar as duas maquinas e atualizar a tabela.
Os atalhos de acesso atualizam a linha da maquina acessada.</p>
<p class="note">As senhas estao visiveis neste arquivo. Mantenha-o no seu computador.
Se alterar a senha dentro do RHEL, esta tabela nao detectara a alteracao automaticamente.</p>
</body></html>
"@
    [IO.File]::WriteAllText("$script:AccessFile.tmp", $html, [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath "$script:AccessFile.tmp" -Destination $script:AccessFile -Force
}

function Get-LabVM($Entry) {
    if (-not $Entry.Id) { throw "Criacao incompleta de $($Entry.Name). Execute INICIAR.cmd para verificar a recuperacao." }
    $vm = Get-VM -ErrorAction Stop | Where-Object Id -eq ([guid]$Entry.Id)
    if (-not $vm) { throw "A VM $($Entry.Name) foi removida do Hyper-V. Execute INICIAR.cmd para recriar somente a VM ausente; os discos antigos serao preservados." }
    if ($vm.Name -ne $Entry.Name -or $vm.Notes -ne "RHCSA-AUTO-v1:$($Entry.Token)") {
        throw "Identidade da VM $($Entry.Name) diferente do registro do laboratorio. Nenhum disco sera alterado."
    }
    return $vm
}

function Get-MissingLabVMs {
    # Uma falha ao consultar Hyper-V deve interromper, nao parecer uma VM excluida.
    $allVMs = @(Get-VM -ErrorAction Stop)
    foreach ($entry in $script:State.VMs) {
        if ($entry.Name -notin @('rhcsa01','rhcsa02')) { throw 'Nome inesperado no registro do laboratorio.' }
        $match = @($allVMs | Where-Object { $entry.Id -and $_.Id.ToString() -eq $entry.Id })
        if ($match.Count -eq 1) {
            if ($match[0].Name -ne $entry.Name -or $match[0].Notes -ne "RHCSA-AUTO-v1:$($entry.Token)") {
                throw "Identidade divergente para $($entry.Name). Nenhuma VM sera substituida."
            }
            if ($entry.Stage -eq 'Creating') { throw "A preparacao de $($entry.Name) foi interrompida. A VM existe e precisa de revisao; nao sera reinstalada automaticamente." }
        } else {
            if ($allVMs | Where-Object Name -eq $entry.Name) {
                throw "Existe outra VM chamada $($entry.Name) com um identificador diferente. Ela sera preservada; resolva o conflito de nome antes de continuar."
            }
            $entry
        }
    }
}

function Repair-MissingLabVMs([string]$SwitchName, [string]$PackageRoot) {
    $missing = @(Get-MissingLabVMs)
    if ($missing.Count -eq 0) { return }
    Write-Host "VM(s) removida(s) do Hyper-V: $($missing.Name -join ', ')."
    Write-Host 'A recriacao instala um RHEL novo somente nessas VMs, em discos novos.'
    Write-Host 'Os discos antigos ficam onde estao. Os dados antigos nao sao importados para a nova VM.'
    $answer = Read-Host 'Digite RECRIAR para continuar ou Enter para sair sem alteracoes'
    if ($answer -ine 'RECRIAR') { throw 'Recriacao cancelada. Nenhum recurso foi alterado.' }
    $isoPath = $script:State.ISO
    if (-not (Test-Path -LiteralPath $isoPath -PathType Leaf)) {
        $isos = @(Get-ChildItem -LiteralPath (Join-Path $PackageRoot 'pasta da iso') -File -Filter '*.iso')
        if ($isos.Count -ne 1) { throw 'Coloque uma unica ISO RHEL 10 Binary DVD em pasta da iso para recriar.' }
        $isoPath = $isos[0].FullName
    }
    Assert-RhelISO $isoPath
    $drive = Get-PSDrive -Name ([IO.Path]::GetPathRoot($script:Root).Substring(0,1)) -PSProvider FileSystem
    if ($drive.Free -lt (($missing.Count * 16 + 2) * 1GB)) { throw 'Espaco insuficiente para os discos novos mantendo os antigos. Libere espaco antes de recriar.' }
    $template = Get-Content -LiteralPath (Join-Path $PackageRoot 'arquivos\instalacao.ks') -Raw
    $backup = Join-Path $script:Root ("estado-anterior-{0}.json" -f [guid]::NewGuid().ToString())
    Copy-Item -LiteralPath $script:StateFile -Destination $backup
    $script:State.ISO = $isoPath
    foreach ($old in $missing) {
        $password = $null
        try {
            if ($old.PSObject.Properties['Password'] -and $old.Password) {
                $password = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([string]$old.Password))
            } else { $password = Read-LabPassword }
            $token = [guid]::NewGuid().ToString()
            $folder = Join-Path $script:Root "$($old.Name)-recriada-$token"
            $entry = [pscustomobject]@{ Name=$old.Name; Id=''; Stage='Creating'; Token=$token; Seed=(Join-Path $folder 'respostas.vhdx'); HostKey=''; IP=''; IPCheckedAt=''; Password=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($password)) }
            # A pasta e unica. Nunca reutilizar ou formatar discos anteriores.
            New-Item -ItemType Directory -Path $folder | Out-Null
            $script:State.VMs = @($script:State.VMs | ForEach-Object { if ($_.Name -eq $old.Name) { $entry } else { $_ } })
            Save-LabState
            Write-AccessTable
            New-AnswerDisk $entry $password $template
            $vm = New-VM -Name $entry.Name -Generation 2 -MemoryStartupBytes 2GB -Path $folder -NewVHDPath (Join-Path $folder 'sistema.vhdx') -NewVHDSizeBytes 16GB -SwitchName $SwitchName
            $entry.Id = $vm.Id.ToString()
            Set-VM -VM $vm -Notes "RHCSA-AUTO-v1:$token" -AutomaticCheckpointsEnabled $false -AutomaticStartAction Nothing -AutomaticStopAction ShutDown
            Save-LabState
            Set-VMMemory -VM $vm -DynamicMemoryEnabled $false -StartupBytes 2GB
            Set-VMProcessor -VM $vm -Count 2 -CompatibilityForMigrationEnabled $false
            Add-VMHardDiskDrive -VM $vm -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 1 -Path $entry.Seed
            $dvd = Add-VMDvdDrive -VM $vm -ControllerNumber 0 -ControllerLocation 2 -Path $isoPath -Passthru
            Set-VMFirmware -VM $vm -EnableSecureBoot On -SecureBootTemplate MicrosoftUEFICertificateAuthority -FirstBootDevice $dvd
            $entry.Stage = 'Prepared'
            Save-LabState
        } finally { $password = $null }
    }
    Write-Host 'VM(s) ausente(s) recriada(s). Os arquivos anteriores foram preservados.'
}

function Get-LabIPv4($Entry) {
    $vm = Get-LabVM $Entry
    foreach ($ip in @(Get-VMNetworkAdapter -VM $vm | ForEach-Object { $_.IPAddresses })) {
        $parsed = $null
        if ([Net.IPAddress]::TryParse($ip, [ref]$parsed) -and $parsed.AddressFamily -eq 'InterNetwork' -and
            $ip -notlike '169.254.*' -and $ip -notlike '127.*' -and $ip -ne '0.0.0.0') { return $ip }
    }
    return $null
}

function Test-SshBanner([string]$Address) {
    $client = New-Object Net.Sockets.TcpClient
    try {
        $task = $client.ConnectAsync($Address, 22)
        if (-not $task.Wait(2000)) { return $false }
        $stream = $client.GetStream()
        $stream.ReadTimeout = 2000
        $buffer = New-Object byte[] 256
        $length = $stream.Read($buffer, 0, $buffer.Length)
        return [Text.Encoding]::ASCII.GetString($buffer, 0, $length).StartsWith('SSH-2.0-')
    } catch { return $false } finally { $client.Dispose() }
}

function Read-LabPassword {
    while ($true) {
        $first = Read-Host 'Crie uma senha para o usuario aluno (minimo 8 caracteres)' -AsSecureString
        $second = Read-Host 'Repita a senha' -AsSecureString
        $a = [IntPtr]::Zero; $b = [IntPtr]::Zero
        try {
            $a = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($first)
            $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($second)
            $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($a)
            $confirm = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b)
            if ($plain -cne $confirm) { Write-Host 'As senhas nao coincidem.'; continue }
            if ($plain.Length -lt 8 -or $plain -match '[^\x20-\x7e]') {
                Write-Host 'Use pelo menos 8 caracteres, sem acentos. Letras, numeros, espacos e simbolos sao aceitos.'
                continue
            }
            return [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($plain))
        } finally {
            if ($a -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($a) }
            if ($b -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) }
            $plain = $null; $confirm = $null
            $first.Dispose(); $second.Dispose()
        }
    }
}

function Assert-RhelISO([string]$Path) {
    $alreadyMounted = (Get-DiskImage -ImagePath $Path).Attached
    try {
        if (-not $alreadyMounted) { Mount-DiskImage -ImagePath $Path -Access ReadOnly | Out-Null }
        $volumes = @(Get-DiskImage -ImagePath $Path | Get-Volume | Where-Object DriveLetter)
        if ($volumes.Count -ne 1) { throw 'Nao foi possivel ler a ISO.' }
        $media = "$($volumes[0].DriveLetter):\"
        $tree = Get-Content -LiteralPath (Join-Path $media '.treeinfo') -Raw
        if ($tree -notmatch '(?m)^version\s*=\s*10(?:\.[^\r\n]+)?\s*$' -or
            $tree -notmatch '(?m)^arch\s*=\s*x86_64\s*$' -or
            $tree -notmatch '(?mi)^family\s*=\s*Red Hat Enterprise Linux\s*$' -or
            -not (Test-Path -LiteralPath (Join-Path $media 'BaseOS\repodata')) -or
            -not (Test-Path -LiteralPath (Join-Path $media 'AppStream\repodata'))) {
            throw 'Use a ISO oficial RHEL 10.x x86_64 Binary DVD (a Boot ISO nao contem os pacotes).'
        }
    } finally {
        if (-not $alreadyMounted -and (Get-DiskImage -ImagePath $Path).Attached) {
            Dismount-DiskImage -ImagePath $Path | Out-Null
        }
    }
}

function New-AnswerDisk($Entry, [string]$PasswordBase64, [string]$Template) {
    # Somente um VHDX recem-criado e inicializado; nenhum disco fisico e selecionado.
    New-VHD -Path $Entry.Seed -Dynamic -SizeBytes 64MB | Out-Null
    try {
        $disk = Mount-VHD -Path $Entry.Seed -Passthru | Get-Disk
        if ($disk.Size -ne 64MB -or $disk.PartitionStyle -ne 'RAW' -or $disk.IsBoot -or $disk.IsSystem) {
            throw 'O disco auxiliar nao passou na verificacao de seguranca.'
        }
        $disk | Initialize-Disk -PartitionStyle MBR | Out-Null
        $partition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -AssignDriveLetter
        $partition | Format-Volume -FileSystem FAT -NewFileSystemLabel OEMDRV -Confirm:$false | Out-Null
        $letter = (Get-Partition -DiskNumber $disk.Number -PartitionNumber $partition.PartitionNumber).DriveLetter
        if (-not $letter) { throw 'Nao foi possivel montar o disco de respostas.' }
        $seedRoot = "${letter}:\"
        $ks = $Template.Replace('@@HOSTNAME@@', "$($Entry.Name).lab.test").Replace('@@TOKEN@@', $Entry.Token)
        [IO.File]::WriteAllText((Join-Path $seedRoot 'ks.cfg'), $ks.Replace("`r`n", "`n"), [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $seedRoot 'password.b64'), $PasswordBase64, [Text.Encoding]::ASCII)
    } finally {
        if ((Get-VHD -Path $Entry.Seed).Attached) { Dismount-VHD -Path $Entry.Seed }
    }
}

function Read-InstallResult($Entry) {
    try {
        $disk = Mount-VHD -Path $Entry.Seed -ReadOnly -Passthru | Get-Disk
        $part = @(Get-Partition -DiskNumber $disk.Number | Where-Object Type -ne 'Reserved')[0]
        if (-not $part.DriveLetter) {
            $part | Add-PartitionAccessPath -AssignDriveLetter
            $part = Get-Partition -DiskNumber $disk.Number -PartitionNumber $part.PartitionNumber
        }
        $seedRoot = "$($part.DriveLetter):\"
        $marker = Join-Path $seedRoot 'success.txt'
        if (-not (Test-Path -LiteralPath $marker) -or (Get-Content -LiteralPath $marker -Raw) -cne $Entry.Token) {
            throw "A VM $($Entry.Name) desligou sem confirmar a instalacao. Os discos foram preservados."
        }
        $key = (Get-Content -LiteralPath (Join-Path $seedRoot 'hostkey.pub') -Raw).Trim()
        if ($key -notmatch '^ssh-ed25519 [A-Za-z0-9+/=]+(?: .*)?$') { throw 'Chave SSH do servidor invalida.' }
        return ($key.Split(' ')[0..1] -join ' ')
    } finally {
        if ((Get-VHD -Path $Entry.Seed).Attached) { Dismount-VHD -Path $Entry.Seed }
    }
}

function Wait-Installed($Entry) {
    $deadline = [DateTime]::UtcNow.AddMinutes(90)
    $reportAt = [DateTime]::MinValue
    while ([DateTime]::UtcNow -lt $deadline) {
        $vm = Get-LabVM $Entry
        if ($vm.State -eq 'Off') { return }
        if ($vm.State -in @('Paused', 'Saved', 'Critical')) { throw "VM $($Entry.Name) em estado $($vm.State). Verifique o Hyper-V e execute INICIAR novamente." }
        if ([DateTime]::UtcNow -ge $reportAt) {
            Write-Host "Instalando $($Entry.Name)... aguarde. Nenhuma escolha no instalador e necessaria."
            $reportAt = [DateTime]::UtcNow.AddSeconds(30)
        }
        Start-Sleep -Seconds 5
    }
    throw "A instalacao de $($Entry.Name) excedeu 90 minutos. Execute INICIAR novamente para continuar aguardando, sem reinstalar."
}

function Wait-LabSSH($Entry) {
    $deadline = [DateTime]::UtcNow.AddMinutes(10)
    while ([DateTime]::UtcNow -lt $deadline) {
        $ip = Get-LabIPv4 $Entry
        if ($ip -and (Test-SshBanner $ip)) { return $ip }
        Start-Sleep -Seconds 5
    }
    throw "O RHEL de $($Entry.Name) foi instalado, mas ainda nao responde por SSH. Confira Default Switch/VPN e execute INICIAR novamente."
}

function Stop-LabGracefully($Entry) {
    $vm = Get-LabVM $Entry
    if ($vm.State -eq 'Off') { return }
    if ($vm.State -ne 'Running') { throw "Estado inesperado para desligar $($Entry.Name): $($vm.State)." }
    Write-Host "Desligando $($Entry.Name) pelo sistema operacional para liberar RAM..."
    Stop-VM -VM $vm -Confirm:$false
    if ((Get-LabVM $Entry).State -ne 'Off') {
        throw "Nao foi possivel desligar $($Entry.Name) normalmente. Use sudo poweroff dentro dela e execute INICIAR novamente."
    }
}
