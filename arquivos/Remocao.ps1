function Invoke-SubscriptionCleanup($Entry, [string]$Address) {
    if ($Entry.HostKey -notmatch '^ssh-ed25519 [A-Za-z0-9+/=]+$') { throw 'Chave SSH registrada invalida. Remocao bloqueada.' }
    $knownHosts = Join-Path $script:Root "known_hosts_remover_$($Entry.Name)"
    [IO.File]::WriteAllText($knownHosts, "$($Entry.Name) $($Entry.HostKey)`n", [Text.Encoding]::ASCII)
    Write-Host "Em $($Entry.Name), informe a senha de aluno para SSH e sudo quando solicitado."
    # && impede clean se unregister falhar. O codigo de saida SSH representa o comando remoto.
    & ssh.exe -tt -o ConnectTimeout=15 -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o "UserKnownHostsFile=$knownHosts" -o "HostKeyAlias=$($Entry.Name)" -o StrictHostKeyChecking=yes "aluno@$Address" 'sudo subscription-manager unregister && sudo subscription-manager clean'
    if ($LASTEXITCODE -ne 0) { throw "unregister/clean nao terminou com sucesso em $($Entry.Name). Esta VM nao sera removida." }
}

function Set-LabRemoved($Entry) {
    $Entry.Stage = 'Removed'
    $Entry.IP = ''
    if ($Entry.PSObject.Properties['Password']) { $Entry.Password = '' }
    if ($Entry.PSObject.Properties['IPCheckedAt']) { $Entry.IPCheckedAt = '' }
    Save-LabState
    Write-AccessTable
}

function Invoke-RemoveLab {
    if (-not (Test-Path -LiteralPath $script:StateFile)) { throw 'Nenhum registro de laboratorio encontrado. Nenhuma VM foi removida.' }
    $script:State = Get-Content -LiteralPath $script:StateFile -Raw | ConvertFrom-Json
    if ($script:State.Version -ne 1 -or @($script:State.VMs).Count -ne 2) { throw 'Registro de laboratorio invalido. Remocao bloqueada.' }
    if (@($script:State.VMs | Where-Object Stage -ne 'Removed').Count -eq 0) { Write-Host 'As duas VMs ja foram removidas por este procedimento.'; return }
    if (-not (Get-Command ssh.exe -ErrorAction SilentlyContinue)) { throw 'Cliente SSH ausente. Instale OpenSSH Client nos Recursos Opcionais do Windows antes de remover.' }
    # Validar todas antes de cancelar assinaturas ou remover qualquer uma.
    foreach ($entry in $script:State.VMs) {
        if ($entry.Name -notin @('rhcsa01','rhcsa02')) { throw 'Nome de VM inesperado. Remocao bloqueada.' }
        if ($entry.Stage -eq 'Removed') { continue }
        if ($entry.Stage -notin @('Ready','Removing')) { throw "$($entry.Name) ainda nao esta pronta para acesso SSH. Remocao bloqueada." }
        if ($entry.Stage -eq 'Removing') {
            $matches = @(Get-VM -ErrorAction Stop | Where-Object Id -eq ([guid]$entry.Id))
            if ($matches.Count -eq 0) {
                # Retoma apenas a janela entre Remove-VM e a gravacao final do estado.
                Set-LabRemoved $entry
                continue
            }
        }
        $null = Get-LabVM $entry
    }
    Write-Host 'Este procedimento cancela o registro Red Hat, limpa as credenciais e remove as VMs do Hyper-V.'
    Write-Host 'Salve seu trabalho. Os arquivos VHDX permanecerao no disco; esta rotina nao os apaga.'
    if ((Read-Host 'Digite REMOVER para confirmar ou Enter para cancelar') -cne 'REMOVER') { Write-Host 'Remocao cancelada.'; return }
    foreach ($entry in $script:State.VMs) {
        if ($entry.Stage -eq 'Removed') { continue }
        $vm = Get-LabVM $entry
        if ($vm.State -eq 'Off') { Start-VM -VM $vm }
        elseif ($vm.State -ne 'Running') { throw "Estado de $($entry.Name) impede acesso SSH. Remocao interrompida." }
        $ip = Wait-LabSSH $entry
        Invoke-SubscriptionCleanup $entry $ip
        Stop-LabGracefully $entry
        $vm = Get-LabVM $entry
        if ($vm.State -ne 'Off') { throw 'A VM nao desligou normalmente. Remocao interrompida.' }
        $entry.Stage = 'Removing'
        Save-LabState
        Remove-VM -VM $vm -Confirm:$false
        Set-LabRemoved $entry
        Write-Host "$($entry.Name): registro cancelado e VM removida. Discos preservados."
    }
    Write-Host 'Remocao concluida. Nenhuma rede do Windows foi removida.'
}
