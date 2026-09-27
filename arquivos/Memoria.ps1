#Requires -Version 5.1
# Assistente interativo; nao precisa de administrador e nao encerra servicos.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$allowed = @('chrome','brave','msedge','Code','ChatGPT','EpicGamesLauncher','HD-Player','uTorrent','TeraBox','TeraBoxUnite')
$session = (Get-Process -Id $PID).SessionId
try {
    Write-Host 'LIBERAR MEMORIA PARA O LABORATORIO'
    Write-Host 'Salve seu trabalho. Voce escolhe quais aplicativos receberao o pedido de fechar.'
    Write-Host 'Nao ha encerramento forcado, limpeza de cache, alteracao no antivirus ou em servicos.'
    while ($true) {
        $os = Get-CimInstance Win32_OperatingSystem
        Write-Host ("`nRAM disponivel: {0:N2} GB de {1:N2} GB utilizaveis pelo Windows." -f ($os.FreePhysicalMemory / 1MB), ($os.TotalVisibleMemorySize / 1MB))
        $groups = @(Get-Process | Where-Object { $_.SessionId -eq $session -and $_.ProcessName -in $allowed } |
            Group-Object ProcessName | Sort-Object { ($_.Group | Measure-Object WorkingSet64 -Sum).Sum } -Descending)
        if ($groups.Count -eq 0) { Write-Host 'Nenhum aplicativo da lista foi encontrado nesta sessao.'; break }
        for ($i=0; $i -lt $groups.Count; $i++) {
            $mb = ($groups[$i].Group | Measure-Object WorkingSet64 -Sum).Sum / 1MB
            Write-Host ('{0}. {1} - {2:N0} MB aproximados ({3} processos)' -f ($i+1), $groups[$i].Name, $mb, $groups[$i].Count)
        }
        Write-Host 'A soma pode incluir memoria compartilhada; nao e uma promessa de memoria liberada.'
        $answer = Read-Host 'Numeros para fechar (ex.: 1,3), A para atualizar ou Enter para sair'
        if ([string]::IsNullOrWhiteSpace($answer)) { break }
        if ($answer -ieq 'A') { continue }
        $selection = @()
        $valid = $true
        foreach ($item in $answer.Split(',')) {
            $index = 0
            if (-not [int]::TryParse($item.Trim(), [ref]$index) -or $index -lt 1 -or $index -gt $groups.Count) { $valid=$false; break }
            $selection += $index - 1
        }
        if (-not $valid) { Write-Host 'Selecao invalida. Nenhum aplicativo foi alterado.'; continue }
        foreach ($index in @($selection | Select-Object -Unique)) {
            $group = $groups[$index]
            $sent = 0
            foreach ($process in $group.Group) {
                try {
                    $process.Refresh()
                    if (-not $process.HasExited -and $process.MainWindowHandle -ne [IntPtr]::Zero) {
                        if ($process.CloseMainWindow()) { $sent++ }
                    }
                } catch { Write-Host "Nao foi possivel solicitar fechamento de $($group.Name): $($_.Exception.Message)" }
            }
            if ($sent -gt 0) { Write-Host "$($group.Name): pedido enviado. Responda a eventuais avisos para salvar nos aplicativos." }
            else { Write-Host "$($group.Name): sem janela acessivel. Feche pelo proprio aplicativo ou icone na bandeja." }
        }
        Start-Sleep -Seconds 3
        Write-Host 'Aplicativos podem manter processos em segundo plano. Confira a memoria disponivel acima apos atualizar.'
    }
    Write-Host 'Depois, execute INICIAR.cmd novamente. Nao apague as VMs existentes.'
} catch {
    Write-Host "Nao foi possivel concluir: $($_.Exception.Message)"
}
