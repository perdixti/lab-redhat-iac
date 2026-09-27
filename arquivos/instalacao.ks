# RHEL 10 / Hyper-V. Tokens substituidos pelo provisionador.
text --non-interactive
cdrom
lang pt_BR.UTF-8
keyboard --vckeymap=br-abnt2 --xlayouts='br'
timezone America/Sao_Paulo --utc
network --bootproto=dhcp --device=link --activate --onboot=yes --hostname=@@HOSTNAME@@
rootpw --lock
user --name=aluno --groups=wheel --iscrypted --password=*
firewall --enabled --service=ssh
selinux --enforcing
services --enabled=sshd,firewalld,chronyd,hypervkvpd
firstboot --disable
skipx
poweroff

# Nunca selecionar o disco auxiliar de respostas para instalar.
%pre --interpreter=/bin/bash --erroronfail
set -eu
python3 - <<'PY'
import json, subprocess
devices = json.loads(subprocess.check_output(['lsblk', '-b', '-J', '-d', '-o', 'NAME,TYPE,SIZE']))['blockdevices']
targets = [d['name'] for d in devices if d['type'] == 'disk' and int(d['size']) == 17179869184]
if len(targets) != 1:
    raise SystemExit('Esperado exatamente um disco novo de 16 GiB')
disk = targets[0]
with open('/tmp/storage.ks', 'w') as out:
    out.write(f'ignoredisk --only-use={disk}\n')
    out.write(f'clearpart --all --initlabel --drives={disk}\n')
    out.write('zerombr\n')
    out.write(f'bootloader --boot-drive={disk}\n')
    out.write(f'part /boot/efi --fstype=efi --size=600 --ondisk={disk}\n')
    out.write(f'part /boot --fstype=xfs --size=1024 --ondisk={disk}\n')
    out.write(f'part swap --size=1024 --ondisk={disk}\n')
    out.write(f'part / --fstype=xfs --size=10240 --grow --ondisk={disk}\n')
PY
%end
%include /tmp/storage.ks

%packages
@core
openssh-server
firewalld
chrony
hyperv-daemons
sudo
python3
lvm2
%end

%post --nochroot --interpreter=/bin/bash --erroronfail --log=/mnt/sysroot/root/lab-install.log
set -eu
mkdir -p /tmp/lab-seed
seed_device=$(readlink -f /dev/disk/by-label/OEMDRV)
seed_mount=$(findmnt -rn -S "$seed_device" -o TARGET | head -n 1)
if [ -n "$seed_mount" ]; then
    mount -o remount,rw "$seed_mount"
    mount --bind "$seed_mount" /tmp/lab-seed
else
    mount -t vfat -o rw "$seed_device" /tmp/lab-seed
fi
# A senha nao e interpolada em shell e nao aparece na linha de comando.
python3 - <<'PY'
import base64, pathlib, subprocess
seed = pathlib.Path('/tmp/lab-seed')
password = base64.b64decode((seed / 'password.b64').read_bytes(), validate=True)
if any(c in password for c in (b'\x00', b'\n', b'\r')):
    raise SystemExit('Senha invalida')
subprocess.run(['chroot', '/mnt/sysroot', '/usr/sbin/chpasswd'], input=b'aluno:' + password + b'\n', check=True)
del password
(seed / 'password.b64').unlink()
PY
mkdir -p /mnt/sysroot/etc/ssh/sshd_config.d
printf 'PasswordAuthentication yes\nPermitRootLogin no\n' > /mnt/sysroot/etc/ssh/sshd_config.d/00-laboratorio.conf
chroot /mnt/sysroot /usr/bin/ssh-keygen -A
# A chave publica permite ao Windows reconhecer o servidor sem prompt de fingerprint.
cp /mnt/sysroot/etc/ssh/ssh_host_ed25519_key.pub /tmp/lab-seed/hostkey.pub
chroot /mnt/sysroot /usr/bin/systemctl enable sshd firewalld chronyd hypervkvpd
printf 'RHCSA-AUTO-v1\n' > /mnt/sysroot/etc/rhcsa-lab-ready
printf '@@TOKEN@@' > /tmp/lab-seed/success.txt
sync
umount /tmp/lab-seed
%end
