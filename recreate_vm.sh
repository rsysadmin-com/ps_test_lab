#!/bin/bash

echo "========= Destroy VM..."
vagrant destroy -f

echo "========= Build new VM..."
vagrant up

echo "========= Enter VM..."
vagrant ssh
