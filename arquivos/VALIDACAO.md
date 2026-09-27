# Validação — 27/09/2026

## Aprovado

- Sintaxe de `Laboratorio.ps1` e `Funcoes.ps1` no Windows PowerShell 5.1.
- Existência dos parâmetros utilizados nos comandos Hyper-V/Storage instalados, incluindo firmware, memória, processador, VHDX e unidades de DVD.
- Construção das regras de acesso por SID, independente do idioma do Windows.
- Compilação dos dois trechos Python incorporados ao Kickstart.
- Sete testes locais: escolha exclusiva do disco de 16 GiB; ordem invertida de discos; interrupção sem disco-alvo; interrupção com dois alvos; senha com aspas, espaços e símbolos enviada por entrada padrão sem shell; rejeição de quebra de linha na senha; tokens do modelo.
- Conferência dos arquivos incluídos no ZIP, inclusive a pasta da ISO.
- Revisao da tabela de acessos: geracao do HTML, preservacao de senha ficticia com espacos/aspas/simbolos, escape de HTML, VM pendente, atualizacao de IP e estado antigo sem senha. Testes sem Hyper-V real.

## Limites reais

Revisao de exclusao manual: testes com Hyper-V simulado para uma/duas VMs ausentes, cancelamento sem mudar estado, conflito de nome com outro GUID, mensagem de recuperacao e falha do servico. Sintaxe PS5.1 aprovada. A recriacao real e o novo boot nao foram executados nesta revisao.

Revisao de memoria: sintaxe de todos os PS1 validada no Windows PowerShell 5.1; teste com substituicoes locais confirmou desligamento solicitado apenas para VM em execucao, nenhuma acao para VM desligada e rejeicao de estado inesperado. Nenhum aplicativo ou VM real foi encerrado. A reducao de pico durante instalacao e o assistente interativo ainda precisam de validacao no host de destino.

Não houve instalação completa de RHEL/boot no Hyper-V nesta entrega. Nenhuma VM do usuário foi criada ou alterada. O caminho OEMDRV, os pacotes, DHCP, KVP e login devem passar pelo piloto com a ISO oficial que será distribuída à turma.

O `ksvalidator` não foi executado: pykickstart não estava instalado e o download foi bloqueado pela conectividade do ambiente. Os comandos foram revisados contra a documentação RHEL 10. A tentativa de executar `bash -n` também foi bloqueada pelo ambiente Windows de execução; não é registrada como teste aprovado.

Os testes locais verificam partes da implementação, não substituem o piloto. Para aceitar o pacote: executar INICIAR sem intervenção no console do instalador, obter PRONTO para ambas as VMs, autenticar com a senha escolhida pelos dois atalhos, usar sudo, conferir SELinux e testar internet e desligamento/reabertura.
