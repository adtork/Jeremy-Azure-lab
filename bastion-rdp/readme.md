az login from your local machine (not WSL) and make sure you select correct credentials

az network bastion rdp --name "myBastionHost" --resource-group "LB-test" --target-resource-id "/subscriptions/xxxxx/resourceGroups/LB-TEST/providers/Microsoft.Compute/virtualMachines/myVM1"
