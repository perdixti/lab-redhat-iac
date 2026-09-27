#!/bin/bash

echo "========================================"
echo " Registro do RHEL - Red Hat"
echo "========================================"
echo

# Precisa executar como root
if [ "$EUID" -ne 0 ]; then
    echo "ERRO: execute este script como root."
    echo "Use: sudo ./registrar-rhel.sh"
    exit 1
fi

# Verifica se já está registrado
if subscription-manager identity &>/dev/null; then
    echo "Esta máquina já está registrada:"
    subscription-manager identity
    echo
else
    echo "Registrando a máquina na Red Hat..."
    echo

    # O próprio subscription-manager solicitará
    # usuário e senha de forma interativa.
    subscription-manager register

    if [ $? -ne 0 ]; then
        echo
        echo "ERRO: não foi possível registrar a máquina."
        exit 1
    fi
fi

echo
echo "========================================"
echo " Verificando registro"
echo "========================================"

subscription-manager identity

echo
echo "========================================"
echo " Habilitando repositórios RHEL 10"
echo "========================================"

subscription-manager repos \
    --enable=rhel-10-for-x86_64-baseos-rpms \
    --enable=rhel-10-for-x86_64-appstream-rpms

echo
echo "Limpando cache do DNF..."
dnf clean all

echo
echo "Repositórios disponíveis:"
dnf repolist

echo
echo "========================================"
echo " Atualizando o sistema"
echo "========================================"

dnf update -y

echo
echo "========================================"
echo " RHEL configurado com sucesso!"
echo "========================================"