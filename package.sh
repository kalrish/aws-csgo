#!/bin/bash

exec zip -- aws-csgo.zip ansible.cfg buildspec.yaml <(aws --query 'Parameter.Value' --output text ssm get-parameter --name '/csgo/ssh-key' --with-decryption) playbook.yaml prepare.sh roles template.json
