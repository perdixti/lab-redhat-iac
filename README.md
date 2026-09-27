# Criação de ambiente para labs Red Hat com IaC

Este pacote automatiza a criação e a instalação de **duas máquinas RHEL 10** para estudar para o RHCSA. Você coloca a ISO na pasta, executa o programa e aguarda as máquinas ficarem disponíveis.

## 1. Baixe a ISO do RHEL

Você pode obter o RHEL gratuitamente pelo programa **Red Hat Developer Subscription for Individuals**, que permite até **16 sistemas físicos ou virtuais**, conforme os termos de uso individual. Cada aluno deve usar sua própria conta. [Condições oficiais](https://developers.redhat.com/terms-and-conditions)

Para baixar:

1. Crie uma conta no [Red Hat Developer](https://developers.redhat.com/register) e aceite os termos.
2. Acesse a [página de downloads do RHEL](https://developers.redhat.com/products/rhel/download).
3. Escolha **RHEL 10.x**, arquitetura **x86_64**, para computadores Intel/AMD.
4. Baixe a **Binary DVD ISO**, que contém os pacotes necessários.

**Não use a Boot ISO, uma imagem ARM ou uma versão beta neste laboratório.**

A assinatura individual dura **um ano** e pode ser renovada gratuitamente. [Como renovar](https://developers.redhat.com/articles/renew-your-red-hat-developer-program-subscription)

## 2. Confira os requisitos

Você precisará de:

- Windows 11 **Pro, Enterprise ou Education**. Este pacote não foi preparado para Windows Home ou Windows Server.
- Virtualização habilitada na BIOS/UEFI.
- Processador Intel/AMD compatível com **x86-64-v3**, exigido pelo RHEL 10. [Requisitos do RHEL](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/interactively_installing_rhel_from_installation_media/system-requirements-and-supported-architectures)
- Pelo menos **42 GB livres no disco do Windows**, depois de baixar a ISO.
- Permissão de administrador no Windows.

O ambiente foi dimensionado para um computador com **16 GB de RAM**.

**O programa não verifica nem exige 6 GB de RAM livre para criar as máquinas.** As duas VMs recebem 2 GB cada; o Windows ainda precisa conseguir disponibilizar memória para iniciá-las.

| Recurso | rhcsa01 | rhcsa02 |
|---|---|---|
| Memória RAM | 2 GB | 2 GB |
| Processadores virtuais | 2 | 2 |
| Disco do sistema | 16 GB | 16 GB |
| Sistema | RHEL 10 mínimo, sem interface gráfica | RHEL 10 mínimo, sem interface gráfica |
| Usuário | `aluno` | `aluno` |

O disco de 16 GB atende ao perfil mínimo, mas exige atenção ao espaço ao instalar novos pacotes.

## 3. Coloque a ISO na pasta

**Extraia o ZIP antes de executar os arquivos.** Depois, coloque a ISO em **pasta da iso**:

```text
rhcsa-automatico
├── pasta da iso
│   └── sua-imagem-rhel-10.iso
├── INICIAR.cmd
├── ACESSAR MAQUINA 1.cmd
├── ACESSAR MAQUINA 2.cmd
├── LEIA PRIMEIRO.md
└── arquivos
```

Não precisa renomear nem extrair a ISO. Deixe **somente uma ISO** nessa pasta.

Mantenha a pasta completa e não mova a ISO durante a instalação.

## 4. Execute a instalação automática

1. Abra **INICIAR.cmd**.
2. Aceite a solicitação de administrador do Windows.
3. Escolha e confirme a senha do usuário **aluno**: no mínimo **8 caracteres, sem acentos**. A mesma senha será usada nas duas VMs.
4. Aguarde aparecer **PRONTO!**.

Se o Hyper-V precisar ser habilitado, o programa solicitará uma reinicialização. Salve seu trabalho, reinicie o Windows e abra **INICIAR.cmd** novamente.

Durante a instalação:

- Mantenha a janela aberta.
- Não suspenda nem desligue o computador.
- Aguarde a instalação das duas máquinas, feita em sequência.

O programa cria as VMs, instala o RHEL, configura usuário, rede e SSH, retira a mídia de instalação e verifica o acesso pelo Windows.

**Não é necessário abrir o Gerenciador do Hyper-V nem responder às telas do instalador.**

## 5. Entenda a rede

O laboratório usa a rede padrão do Hyper-V, com **NAT e endereçamento automático**:

- As VMs podem acessar a internet pela conexão do Windows.
- O próprio Windows consegue acessar as VMs diretamente.
- Não é necessário configurar IP, DNS ou portas no roteador.
- O pacote não publica o SSH das VMs para outros computadores da rede.

VPNs e restrições da rede local podem interferir na conectividade.

## 6. Consulte os dados de acesso

O programa cria **ACESSOS.html** na mesma pasta de **INICIAR.cmd**.

Abra esse arquivo no navegador para consultar:

| Nome da VM | IP | Usuário | Senha |
|---|---|---|---|
| rhcsa01 | Preenchido automaticamente | aluno | Senha escolhida |
| rhcsa02 | Preenchido automaticamente | aluno | Senha escolhida |

A tabela é preenchida conforme cada máquina fica pronta. Durante a instalação, a segunda VM pode aparecer como pendente.

Os IPs podem mudar. Execute **INICIAR.cmd** novamente para verificar as duas máquinas e atualizar a tabela. Com o laboratório existente corretamente registrado, isso **não reinstala o RHEL**.

**As senhas ficam visíveis no arquivo.** Não compartilhe uma cópia preenchida com outras pessoas. Se alterar a senha dentro do RHEL, a tabela continuará mostrando a senha inicial.

## 7. Acesse as máquinas

Abra:

- **ACESSAR MAQUINA 1.cmd** para entrar na `rhcsa01`.
- **ACESSAR MAQUINA 2.cmd** para entrar na `rhcsa02`.

Aceite a permissão do Windows e digite sua senha. Esses arquivos ligam a VM, se estiver desligada, descobrem o IP atual e atualizam sua linha na tabela.

Se o cliente SSH estiver ausente, o programa tentará instalá-lo pelo Windows Update, o que exige acesso à internet.

Você também pode usar o Terminal do Windows:

```powershell
ssh aluno@IP_DA_VM
```

Substitua `IP_DA_VM` pelo endereço de **ACESSOS.html**. Ao digitar a senha no SSH, os caracteres não aparecem na tela; isso é normal.

Para executar comandos administrativos, use `sudo`. Para desligar a VM ao terminar:

```bash
sudo poweroff
```

Na próxima aula, abra o arquivo **ACESSAR MAQUINA** correspondente.

## Se aparecer um erro

Copie a mensagem da janela e envie ao professor.

- **Já existe uma VM com o mesmo nome:** o programa não substitui máquinas de outro laboratório.
- **Memória insuficiente ao iniciar:** feche programas pesados e tente novamente.
- **Instalação interrompida:** execute **INICIAR.cmd** novamente para tentar continuar. Se houver erro, preserve os arquivos e procure o professor.
- **Sem acesso SSH:** informe a mensagem apresentada; o problema pode envolver a rede padrão do Hyper-V, VPN ou serviços da VM.

Não apague as máquinas nem edite os arquivos internos para tentar corrigir o problema.

## Nota para o professor

Antes de distribuir o pacote à turma, faça **um piloto completo no Hyper-V com a mesma ISO que os alunos usarão**. Confirme a instalação sem intervenção, o acesso às duas VMs, a senha, o `sudo` e a tabela de acessos.

Os scripts passaram por verificações locais, mas o processo completo ainda precisa desse teste.

A instalação utiliza os pacotes da ISO. **O registro da assinatura Red Hat e as atualizações posteriores não são automatizados.** Distribua o ZIP original, sem arquivos de acesso preenchidos ou credenciais de outro aluno.
