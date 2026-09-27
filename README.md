# Criação de ambiente para Labs RedHat com IaC

---

# Adiquira a ISO para criação das VMs

## RHEL 10.x gratuito para estudar para o RHCSA

Você pode baixar o **RHEL 10.x original gratuitamente** pelo programa **Red Hat Developer Subscription for Individuals**. Ele permite até **16 máquinas físicas ou virtuais para uso pessoal**, o que atende ao seu laboratório de estudos. [Condições oficiais](https://www.redhat.com/en/resources/red-hat-enterprise-linux-subscription-guide)

O caminho é:

1. Crie uma conta gratuita no [Red Hat Developer](https://developers.redhat.com/register) e aceite os termos do programa.
2. Acesse a [página oficial de downloads do RHEL](https://developers.redhat.com/products/rhel/download).
3. Selecione uma versão **10.x**. Para um PC Intel/AMD, escolha **x86_64**.
4. Prefira a **DVD ISO**, que contém os pacotes para instalação. A **Boot ISO** depende de acesso aos repositórios pela rede. [Downloads e tipos de imagem](https://access.redhat.com/downloads/content/rhel)

A assinatura dura **12 meses e pode ser renovada gratuitamente**. É a assinatura individual, com suporte por conta própria. [Como obter e renovar](https://access.redhat.com/solutions/4078831)

---

# Duas máquinas RHEL para estudar

Cada máquina terá **2 GB de RAM, 2 processadores virtuais e um disco de 16 GB**. A rede será automática, usando a rede padrão do Hyper-V.

## 1. Coloque a ISO na pasta

Extraia o ZIP. Dentro da pasta extraída, coloque sua ISO em **pasta da iso**:

```text
rhcsa-simples
├── pasta da iso
│   └── sua-imagem-rhel-10.iso
├── CRIAR MAQUINAS.cmd
├── Criar-VMs.ps1
└── LEIA-ME.md
```

Não precisa renomear nem extrair a ISO. Deixe somente uma ISO nessa pasta: **RHEL 10 x86_64 Binary DVD**.

## 2. Crie as máquinas

Clique com o botão direito em **CRIAR MAQUINAS.cmd → Executar como administrador**.

O script detecta a ISO e cria **rhcsa01** e **rhcsa02**. Depois abre o Gerenciador do Hyper-V. Não precisa editar código.

É necessário ter Hyper-V habilitado no Windows 10/11 Pro, Enterprise ou Education. Se ainda não estiver, procure **Ativar ou desativar recursos do Windows**, marque **Hyper-V** e reinicie. Deixe pelo menos 6 GB de RAM livres e 40 GB livres no disco do Windows antes de executar.

## 3. Instale o RHEL

No Gerenciador do Hyper-V, faça uma máquina de cada vez:

1. Clique duas vezes em **rhcsa01** e clique em **Iniciar**. Pressione uma tecla se aparecer a mensagem para iniciar pelo DVD.
2. Selecione **Install Red Hat Enterprise Linux**.
3. Escolha idioma e teclado. Em software, escolha **Minimal Install**, sem interface gráfica.
4. Em destino da instalação, selecione o disco de **16 GB** e deixe o particionamento **automático**.
5. Em rede, **ative a conexão Ethernet** e mantenha IP e DNS automáticos. Não preencha IP manualmente.
6. Crie o usuário **aluno**, marque **administrador** e escolha sua senha. Inicie a instalação.
7. Ao terminar, reinicie e entre com `aluno`. Se voltar ao menu da ISO, desligue a VM pelo Hyper-V e vá a **Configurações → Unidade de DVD → Nenhum**. Depois inicie novamente.

Repita os mesmos passos em **rhcsa02**. Não execute novamente o arquivo de criação para usar as máquinas.

## 4. Acesse suas máquinas

Você já pode usar o terminal pela janela da VM: abra o **Gerenciador do Hyper-V**, clique duas vezes na máquina, inicie e entre com sua senha.

Se preferir acessar pelo Terminal do Windows, execute dentro de cada RHEL:

```bash
sudo systemctl enable --now sshd
sudo systemctl enable --now firewalld
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload
hostname -I
```

Anote o endereço IPv4 mostrado, por exemplo `172.20.10.25`. No Terminal do Windows, use o endereço da sua VM:

```powershell
ssh aluno@172.20.10.25
```

O IP é automático e pode mudar. Quando terminar os estudos, desligue dentro de cada VM com `sudo poweroff`.

**Se algo impedir a criação:** copie a mensagem da janela e me envie. Se já existem VMs chamadas rhcsa01/rhcsa02, o script para sem substituí-las. A criação da infraestrutura é automática; a instalação do RHEL segue os passos acima. Sintaxe validada no PowerShell 5.1; instalação e boot ainda dependem de teste na sua máquina.

Referência da rede automática: [Microsoft — Default Switch](https://techcommunity.microsoft.com/t5/virtualization/what-s-new-in-hyper-v-for-windows-10-fall-creators-update/bc-p/2267078).













