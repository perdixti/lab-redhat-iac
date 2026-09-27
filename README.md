# Criação de ambiente para labs Red Hat com IaC

Este laboratório cria e instala automaticamente **duas máquinas RHEL 10** para estudar para o RHCSA. Você não precisa configurar VMs, rede ou responder às telas de instalação.

## 1. Baixe a ISO do RHEL

Você pode obter o RHEL gratuitamente pelo programa **Red Hat Developer Subscription for Individuals**, que permite até **16 sistemas físicos ou virtuais**, conforme os termos de uso individual. Cada aluno deve usar sua própria conta. [Condições oficiais](https://developers.redhat.com/terms-and-conditions)

Para baixar:

1. Crie uma conta no [Red Hat Developer](https://developers.redhat.com/register) e aceite os termos.
2. Acesse a [página de downloads do RHEL](https://developers.redhat.com/products/rhel/download).
3. Escolha **RHEL 10.x**, arquitetura **x86_64** para computadores Intel/AMD.
4. Baixe a **Binary DVD ISO**, que contém os pacotes necessários à instalação.

**Não use a Boot ISO neste laboratório.**

A assinatura individual tem duração de **um ano** e pode ser renovada gratuitamente. [Como renovar](https://developers.redhat.com/articles/renew-your-red-hat-developer-program-subscription)

## 2. Confira os requisitos

Você precisará de:

- Windows 11 **Pro, Enterprise ou Education**.
- Virtualização habilitada na BIOS/UEFI e processador compatível com RHEL 10.
- Pelo menos **6 GB de RAM livres** antes de iniciar.
- Pelo menos **42 GB livres no disco do Windows**, além do espaço ocupado pela ISO.
- Permissão de administrador no Windows.

O ambiente foi dimensionado para um computador com **16 GB de RAM**.

| Recurso | rhcsa01 | rhcsa02 |
|---|---|---|
| Memória RAM | 2 GB | 2 GB |
| Processadores virtuais | 2 | 2 |
| Disco | 16 GB | 16 GB |
| Sistema | RHEL 10 mínimo, sem interface gráfica | RHEL 10 mínimo, sem interface gráfica |
| Usuário | `aluno` | `aluno` |

A rede usa **NAT**: as VMs têm saída para a internet e o próprio Windows consegue acessá-las. IP e DNS são configurados automaticamente.

## 3. Coloque a ISO na pasta

Extraia o pacote ZIP e coloque sua ISO dentro de **pasta da iso**:

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

## 4. Execute a instalação automática

1. Abra **INICIAR.cmd**.
2. Aceite a solicitação de administrador do Windows.
3. Escolha e confirme a senha do usuário **aluno**. Ela será usada nas duas VMs.
4. Aguarde aparecer **PRONTO!**.

Se o Hyper-V precisar ser habilitado, o programa solicitará uma reinicialização. Reinicie o Windows e abra **INICIAR.cmd** novamente.

Durante a instalação, mantenha a janela aberta e não suspenda o computador. O programa cria as VMs, instala o RHEL, configura o usuário e o SSH, retira a mídia de instalação e verifica o acesso.

**Não é necessário abrir o Gerenciador do Hyper-V nem selecionar opções no instalador do RHEL.**

## 5. Consulte os dados de acesso

O programa cria **ACESSOS.html** na mesma pasta de **INICIAR.cmd**.

Abra esse arquivo no navegador para consultar:

| Nome da VM | IP | Usuário | Senha |
|---|---|---|---|
| rhcsa01 | Preenchido automaticamente | aluno | Senha escolhida |
| rhcsa02 | Preenchido automaticamente | aluno | Senha escolhida |

Os IPs podem mudar. Para verificar as duas máquinas e atualizar a tabela, execute **INICIAR.cmd** novamente. Isso não reinstala o laboratório existente.

As senhas ficam visíveis nesse arquivo. Mantenha-o no seu computador. Se trocar uma senha dentro do RHEL, a tabela não será atualizada automaticamente com a nova senha.

## 6. Acesse as máquinas

Abra:

- **ACESSAR MAQUINA 1.cmd** para entrar na `rhcsa01`.
- **ACESSAR MAQUINA 2.cmd** para entrar na `rhcsa02`.

Aceite a permissão do Windows e digite a senha escolhida. Esses arquivos ligam a VM, se necessário, e descobrem seu IP atual.

Você também pode usar o Terminal do Windows:

```powershell
ssh aluno@IP_DA_VM
```

Substitua `IP_DA_VM` pelo endereço informado em **ACESSOS.html**.

Para executar comandos administrativos dentro do RHEL, use `sudo`. Para desligar a VM ao terminar:

```bash
sudo poweroff
```

Na próxima aula, basta abrir o arquivo **ACESSAR MAQUINA** correspondente.

## Se aparecer um erro

Copie a mensagem da janela e envie ao professor. Não apague as VMs para tentar novamente.

Se já existirem máquinas chamadas **rhcsa01** ou **rhcsa02** de outro laboratório, o programa interrompe a criação sem substituí-las.

**Nota para o professor:** os scripts passaram por verificações locais, mas a instalação completa ainda precisa de um piloto no Hyper-V com a ISO escolhida antes da distribuição à turma. O registro da assinatura Red Hat e as atualizações posteriores não fazem parte da instalação automática.
