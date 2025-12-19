Command to run:
```bash
ansible-playbook apply_changes.yml -e group=lnx_security

# OR
# if using custom inventory file then...
ansible-playbook -i hosts.ini apply_changes.yml -e group=lnx_security
```