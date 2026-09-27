# Notas do professor

## Objetivo e escopo

Este pacote substitui os anteriores para novas instalações. Cria `rhcsa01` e `rhcsa02`, instala RHEL 10.x Minimal a partir da ISO oficial, define usuário/senha, configura SSH/firewall/SELinux, retira as mídias e verifica o acesso TCP/SSH a partir do Windows. Os alunos só usam os três arquivos CMD e a pasta da ISO.

O Hyper-V é habilitado pelo script se necessário; quando houver reinicialização pendente, o aluno precisa reiniciar o Windows e executar o mesmo arquivo novamente. BIOS/UEFI, Windows Home e políticas corporativas não são corrigidos pelo pacote. A instalação do cliente SSH do Windows, se ausente, depende de acesso ao Windows Update.

## Rede e acesso

Usa o **Default Switch** já administrado pelo Windows cliente, que fornece NAT/DHCP. Não cria uma segunda instância WinNAT, não mexe no roteador, não cria VLAN nem redireciona portas para a LAN. O Windows host acessa diretamente o IPv4 da VM. VPNs e políticas locais podem interferir; a instalação só informa “PRONTO” após receber um banner SSH de ambas as VMs.

Os endereços podem mudar. Os arquivos de acesso consultam os IPs atuais pelo Hyper-V; por isso instalam `hyperv-daemons` e habilitam `hypervkvpd` no guest. Cada servidor tem sua própria chave SSH. A chave pública é recolhida pelo disco auxiliar durante a instalação e usada pelos atalhos para verificar a identidade do servidor sem pedir confirmação de fingerprint. Nenhuma chave privada SSH é extraída da VM.

Referência: [Microsoft — Default Switch](https://techcommunity.microsoft.com/t5/virtualization/what-s-new-in-hyper-v-for-windows-10-fall-creators-update/bc-p/2267078). O pacote requer Windows cliente; não usa o mesmo fluxo em Windows Server.

## Instalação automática

Cada VM recebe a ISO DVD e um pequeno VHDX FAT rotulado `OEMDRV` com `ks.cfg` na raiz. O instalador detecta esse volume automaticamente. A ISO original não é alterada. O menu original pode aguardar seu timeout e realizar a checagem de mídia antes da instalação; não é necessário digitar no console. Use ISO final oficial, não beta, Boot ISO ou imagem de nuvem.

O Kickstart seleciona exatamente um disco de 16 GiB, exclui o disco auxiliar do particionamento, instala os pacotes a partir da mídia, prepara o acesso, grava uma confirmação exclusiva da VM e desliga. O Windows confere essa confirmação, retira o disco auxiliar e a ISO, prioriza o disco do sistema e inicia a VM. O estado fica em `%ProgramData%\RHCSA-Automatico\estado.json`.

Referência: [Red Hat — início automático por volume OEMDRV](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/automatically_installing_rhel/starting-kickstart-installations).

## Recursos e credenciais

O programa gera **ACESSOS.html** na pasta do pacote, com nome da VM, IP, usuario e senha escolhida. O arquivo e refeito ao verificar cada VM e registra o horario da ultima verificacao de cada IP. Execute INICIAR para atualizar ambas; um atalho de acesso atualiza somente a VM acessada. O arquivo aparece inicialmente com a segunda VM pendente enquanto a instalacao dela termina.

Para recriar a tabela depois de reiniciar o Windows, as senhas tambem ficam no `estado.json`, na pasta restrita a administradores/SYSTEM. A tabela HTML e legivel por quem tiver acesso a pasta do pacote. **Distribua o ZIP original; nao redistribua uma pasta ja usada contendo ACESSOS.html ou o estado local.** As senhas sao escapadas como texto no HTML. Se o aluno mudar a senha pelo RHEL, a tabela continuara mostrando a senha inicial. Registros criados por pacotes anteriores nao possuem senha recuperavel; nesse caso a tabela informa que ela nao foi registrada, sem inventar nem redefinir credenciais.

- Cada VM: geração 2, 2 vCPU, 2 GiB RAM fixa e 16 GiB VHDX dinâmico; sem discos extras ou checkpoints automáticos.
- Partições: EFI 600 MiB, boot 1 GiB, swap 1 GiB, restante para raiz XFS. O disco de 16 GiB exige controlar espaço ao instalar muitos pacotes.
- Secure Boot habilitado com o modelo Microsoft UEFI Certificate Authority; CPU com x86-64-v3 necessária para RHEL 10.
- `aluno` pode usar sudo com sua senha. Root sem login por senha e sem SSH. SELinux Enforcing e firewalld ativos.
- A senha é solicitada localmente duas vezes. Não aparece em argumentos de processo ou no código. Durante o preparo, ela fica temporariamente codificada em Base64 no disco auxiliar: **Base64 não é criptografia**. A pasta do laboratório restringe acesso a SYSTEM e administradores; o arquivo é removido pelo instalador e o VHDX auxiliar é removido após confirmação. Isso não equivale a apagamento forense. Em falha, o disco pode permanecer protegido na pasta; não o distribua aos alunos nem o publique.
- Não grave senhas reais da Red Hat nesse pacote. Cada aluno escolhe uma senha própria do laboratório.

## Retomada e falhas

Exclusao manual de uma VM: INICIAR detecta o GUID ausente e oferece recriacao apos digitar RECRIAR. Isso e uma instalacao nova da VM ausente, nao recuperacao de seu sistema antigo. Cria uma pasta com identificador unico, preserva todos os discos anteriores e copia o estado anterior para um arquivo de backup na pasta restrita do laboratorio. Mantem a senha registrada, quando disponivel, e limpa os campos antigos de IP/chave da VM recriada. Uma VM com o mesmo nome e outro GUID impede a recriacao para nao assumir propriedade de recursos externos. Falhas de consulta ao Hyper-V tambem interrompem; nao sao tratadas como exclusao. Interrupcoes no meio da preparacao de uma VM existente continuam exigindo revisao, sem apagar recursos automaticamente.

O instalador agora desliga normalmente cada VM que iniciou para validacao antes de seguir para a proxima. Uma VM em fase de primeiro boot tambem e desligada apos a validacao em uma retomada. VMs ja prontas e em uso nao sao desligadas silenciosamente: se houver instalacao pendente, o programa pede escolha explicita; caso contrario preserva as que ja estavam ligadas. Nao ha reducao da RAM configurada, nem corte forcado de energia. A tabela guarda o ultimo IP verificado, mesmo com a VM desligada; use o atalho de acesso para liga-la e atualizar seu endereco.

**LIBERAR MEMORIA.cmd** e opcional, executado sem elevacao: lista aplicativos conhecidos da sessao do aluno e usa CloseMainWindow somente para os selecionados. O programa pode solicitar salvar documentos ou manter processos de fundo. Nao modifica servicos, Defender, arquivo de paginacao, cache ou memoria das VMs. O consumo exibido e uma estimativa por working set; memoria compartilhada pode entrar na soma. Nao garante uma quantidade de RAM liberada. A remocao da verificacao de 6 GB permanece; a alocacao real no inicio das VMs continua sendo responsabilidade do Hyper-V.

Reexecutar `INICIAR.cmd` usa o estado existente e verifica a identidade das VMs, sem reinstalar sistemas já preparados. Se a janela fechar durante a instalação, abra o mesmo arquivo para continuar o acompanhamento. Se a máquina desligar antes de completar o Kickstart, o pacote recusa declarar sucesso e preserva os discos.

Uma interrupção durante a criação inicial pode exigir intervenção do professor. Conflitos com VMs de pacotes anteriores não são resolvidos apagando dados: os scripts param. Não edite o estado para forçar retomada. As VMs existentes devem ser preservadas/exportadas e o conflito resolvido antes de adotar este pacote.

O limite de espera é 90 minutos por instalação e 10 minutos para o SSH. Em falha, abra o console da VM para diagnosticar. No RHEL, o log da pós-instalação é `/root/lab-install.log`; no instalador também há os logs do Anaconda. Não existe rollback destrutivo automático.

## Atualizações e assinatura

A instalação usa os pacotes da ISO e não depende de credenciais Red Hat. O registro da assinatura e as atualizações não são automatizados. Para usar os repositórios oficiais depois, cada aluno precisa de acesso apropriado e pode executar `sudo subscription-manager register`. A mídia não é incluída no ZIP.

## Validação antes de distribuir à turma

Consulte `VALIDACAO.md`. É necessário fazer um piloto completo com a mesma ISO que os alunos usarão: executar INICIAR sem tocar no console, esperar as duas VMs prontas e abrir os dois acessos com a senha definida. Validar também `sudo`, `getenforce`, DNS/internet, desligamento e reabertura. A automação está implementada, mas a validação de sintaxe isoladamente não prova que a ISO escolhida completou a instalação no hardware da turma.
