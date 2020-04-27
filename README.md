# BOSH Deployed K8s in Openstack

## Requirements

- yq - https://mikefarah.gitbook.io/yq/
- jq - https://stedolan.github.io/jq/
- direnv - https://direnv.net/
- docker - https://docs.docker.com/engine/install/ubuntu/

## Steps

### Step 1

First step, clone the repo and get the submodules

```
git submodule init
git submodule update
```

### Step 2

Build the docker image that is required for the `deploy` command

```
./deploy build
## or pull it
docker pull shreddedbacon/openstack-ansible
```

### Step 3

Copy the .envrc-example to .envrc

```
cp .envrc-example .envrc
```

Modify `.envrc` to suit your openstack keystone user/auth credentials

```
export OS_PROJECT_NAME=admin
export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=secretadminpassword
export OS_AUTH_URL=http://your.openstack.url:5000/v3
```

Then allow `direnv` to run in the root of the repo

```
direnv allow
```

Once that is set up, it may complain a bit or download some extra utils for BOSH

### Step 4

Modify `openstack-setup/config.yml` to suit your preference

```
cp openstack-setup/config-example.yml openstack-setup/config.yml
```

Once you're ready, provision the infra

```
./deploy ansible-playbook openstack-setup/provision.yml
```

This step can take a while as we pave out the project, networks, security groups and loadbalancers in the new project

### Step 5

Create a generic key that will be used to provision VMs in Openstack

```
./deploy genkey
```

This process automatically generates an ssh key into the `keypair/` directory for usage by openstack and when provisioning VMs with BOSH

### Step 6

Deploy the Jumpbox, we will use this to interact with our BOSH director that we will create next.

This step will automatically assign a floating IP address to the jumpbox for future commands to use

```
./deploy jumpbox create
```

This may take a few minutes as it will need to download additional resources and then start the VM in openstack

### Step 7

Once jumpbox is ready, start the sock tunnel in a new terminal, this will try to keep a tunnel open for as long as the process is running
It is required whenever you want to interact with the BOSH director

```
./start-socks-tunnel.sh
```

This process copies the automatically generated jumpbox ssh key into the `keypair/` directory for usage

### Step 8

With the socks tunnel running, we can deploy the BOSH director now.

We will be using BUCC for this (https://github.com/starkandwayne/bucc) as it makes deploying BOSH/UAA/Credhub/Concourse easy.
You don't need to clone this as it is included as a submodule in this repository

First run `bucc up --cpi=openstack` to pre-populate the vars yml file (for use with raw bucc commands), then use deploy to `bucc up`

```
bucc up --cpi=openstack
./deploy bucc up
```

> The `bucc-root/vars.yml` file will look a bit funky, we only populate it with stuff that is relevant for `bucc env` so we don't break out direnv environment variables

### Step 9

Once BUCC is up, we need to refresh our `direnv` before we can use our BOSH director
We need to now tell our director how to use openstack, and more specifically how our infrastrucutre has been paved
We also need to add a dns runtime config for use in k8s

```
direnv allow
./deploy update-cloud-config
./deploy update-runtime-config
```

### Step 10

We can't install k8s without the right stemcell, lets upload it now. This will upload the image into openstack via the directon, and then our director will know which images it can use for deploying its VMs

```
./deploy kubo-stemcell
```

### Step 11

Lets get k8s running

```
./deploy kubo
```

> If you encounter a failed deployment with errors with the following, try `./deploy kubo` one more time, the openstack api/vm may not have been ready in time
>
> ```
>  Error: CPI error 'Bosh::Clouds::CloudError' with message 'Load balancer pool membership with pool id 'a80deb02-98b3-4d0c-b23c-c81729d49502', ip '10.20.1.46', and port '32443' supposedly exists, but cannot be found.' in 'create_vm' CPI method (CPI request ID: 'cpi-533242'
> ```

### Step 12

Once that deployment is done, we need to run an errand to set up the cluster a bit more that couldnt be done in the initial deployment

```
./deploy kubo-errands
```

### Step 13

Once the errands are complete, you can set the kubeconfig

```
./deploy set-kubo-config
```

Once you've got your Kubeconfig, you can stop the socks tunnel. Just remember you'll need that tunnel for doing anything with BOSH

### Step 14

Deploy a default storage class that allows k8s to provision cinder volumes

```
./deploy storage-class
```

### Step 15

Ingress! K8s will need an ingress controller if you want to expose services

```
./deploy ingress
```

### Step 16

Demo app (modify the hostname to suit whatever is pointing to your loadbalancer ip address)

```
kubectl apply -f kubernetes/demo/demo-music.yml
```

In a short time you should be able to access it in the browser!

## Helpers

`./deploy X` where X could be:

- `jumpbox-certs` to clear out jumpbox certificates in the event they expire or need to be regenerated
  - run `./deploy jumpbox` after doing this
- `get-kubo-token` to get the admin token from your kube config for whatever reason
- `cert-manager` to install certmanager
  - see `kubernetes/cert-manager/` for yaml files if you want to customize
- `destroy-kubo` if you want to tear down your k8s
- `ansible-playbook destroy.yml` if you want to tear down the infrastructure that was paved
- `jumpbox-ip` to get the external IP of the jumpbox server
- `kubo-ip` to get the external IPs of any loadbalancers
