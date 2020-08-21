#!/usr/bin/env bash

########################
# include the magic
########################
source ./demo/demo-magic.sh

clear

DEMO_PROMPT="${GREEN}➜ ${GREEN}\W "

TYPE_SPEED=35

p "ssh-keygen -t rsa -b 4096 -C 'jonahjones094@gmail.com' -f ~/.ssh/gitopsworkshop_rsa"

pe "cat ~/.ssh/gitopsworkshop_rsa"

wait

p "kubectl create ns flux"

p "helm repo add fluxcd https://charts.fluxcd.io"

p "helm upgrade -i flux fluxcd/flux --wait --namespace flux --set git.url=git@github.com:jonahjon/gitopsworkshop.git --set git.pollInterval=1m"

p "kubectl -n flux logs deployment/flux | grep identity.pub | cut -d '' -f2"

wait

pe "kubectl apply -f https://raw.githubusercontent.com/fluxcd/helm-operator/master/deploy/crds.yaml"

p "helm upgrade -i helm-operator fluxcd/helm-operator --wait --namespace flux --set git.ssh.secretName=flux-git-deploy --set helm.versions=v3"

pe "kubectl get pods -n flux"

TYPE_SPEED=30

p "mkdir namespaces"

pe "cat << EOF > namespaces/appmesh-system.yaml
---
apiVersion: v1
kind: Namespace
metadata:
  labels:
    name: appmesh-system
  name: appmesh-system
EOF
"

p "kubectl apply -f namespaces/appmesh-system.yaml"

pe "kubectl get ns"

p "mkdir appmesh-system"

pe "curl https://raw.githubusercontent.com/aws/eks-charts/v0.0.19/stable/appmesh-controller/crds/crds.yaml -o appmesh-system/crds.yaml"

TYPE_SPEED=90

pe "cat << EOF > appmesh-system/appmesh-controller.yaml
---
apiVersion: helm.fluxcd.io/v1
kind: HelmRelease
metadata:
  name: appmesh-controller
  namespace: appmesh-system
spec:
  releaseName: appmesh-controller
  chart:
    repository: https://aws.github.io/eks-charts/
    name: appmesh-controller
    version: 0.6.1
EOF
"

TYPE_SPEED=50

p "git add -A"

p 'git commit -m "adding in appmesh controller"'

p "git push"

TYPE_SPEED=90

pe "cat << EOF > appmesh-system/appmesh-injector.yaml
---
apiVersion: helm.fluxcd.io/v1
kind: HelmRelease
metadata:
  name: appmesh-inject
  namespace: appmesh-system
spec:
  releaseName: appmesh-inject
  chart:
    repository: https://aws.github.io/eks-charts/
    name: appmesh-inject
    version: 0.9.0
  values:
    mesh:
      create: true
      name: apps
EOF
"

pe "kubectl get pods -n appmesh-system"

TYPE_SPEED=90

pe "cat << EOF > appmesh-system/appmesh-prometheus.yaml
---
apiVersion: helm.fluxcd.io/v1
kind: HelmRelease
metadata:
  name: appmesh-prometheus
  namespace: appmesh-system
spec:
  releaseName: appmesh-prometheus
  chart:
    repository: https://aws.github.io/eks-charts/
    name: appmesh-prometheus
    version: 0.3.0
EOF
"

TYPE_SPEED=50

p "git add -A"

p 'git commit -m "adding in appmesh prometheus"'

p "git push"

pe "kubectl get pods -n appmesh-system"

pe "aws appmesh list-meshes"

pe "kubectl get meshes -A"

pe "cat << EOF > namespaces/amazon-cloudwatch.yaml
---
apiVersion: v1
kind: Namespace
metadata:
  labels:
    name: amazon-cloudwatch
  name: amazon-cloudwatch
EOF
"

p "git add -A"

p 'git commit -m "adding in container insights namespace"'

p "git push"

pe "kubectl get ns"

p "mkdir amazon-cloudwatch"

pe 'curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluentd-quickstart.yaml | sed "s/{{cluster_name}}/gitopsworkshop/;s/{{region_name}}/us-west-2/" > amazon-cloudwatch/cwagent-fluentd-quickstart.yaml'

pe 'curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/prometheus-beta/k8s-deployment-manifest-templates/deployment-mode/service/cwagent-prometheus/prometheus-eks.yaml > amazon-cloudwatch/cwagent-prometheus-eks.yaml'

pe 'echo "edit out namespace from curl content"'

wait

p "git add -A"

p 'git commit -m "adding in container insights fluentd daemonssets"'

p "git push"

pe "kubectl get pods -n amazon-cloudwatch"

wait

TYPE_SPEED=90

pe "cat << EOF > namespaces/apps.yaml
---
apiVersion: v1
kind: Namespace
metadata:
  labels:
    name: apps
    appmesh.k8s.aws/sidecarInjectorWebhook: enabled
  name: apps
EOF
"

TYPE_SPEED=50

p "git add -A"

p 'git commit -m "adding in container insights fluentd daemonssets"'

p "git push"

p "mkdir apps"

pe "curl https://weaveworks-gitops.awsworkshop.io/40_workshop_4_hipo-teams/60_install-pod-info/deploy.files/1-podinfo.yaml -o apps/1-podinfo.yaml"

pe "curl https://weaveworks-gitops.awsworkshop.io/40_workshop_4_hipo-teams/60_install-pod-info/deploy.files/2-podinfo-virtual-nodes.yaml -o apps/2-podinfo-virtual-nodes.yaml"

pe "curl https://weaveworks-gitops.awsworkshop.io/40_workshop_4_hipo-teams/60_install-pod-info/deploy.files/3-podinfo-virtual-services.yaml -o apps/3-podinfo-virtual-services.yaml"

pe "curl https://weaveworks-gitops.awsworkshop.io/40_workshop_4_hipo-teams/60_install-pod-info/deploy.files/4-podinfo-placeholder-services.yaml -o apps/4-podinfo-placeholder-services.yaml"

pe "git add -A"

pe 'git commit -m "adding in virtual svc, virtualnode, and apps"'

pe "git push"

pe "kubectl get pods,svc -n apps"

pe "kubectl get virtualservices,virtualnodes,svc -n apps"

pe "aws appmesh list-virtual-routers --mesh-name=apps"

pe "aws appmesh describe-route --mesh-name=apps --virtual-router-name=backend-podinfo-router-apps --route-name=podinfo-route"

pe "export FRONTEND_NAME=$(kubectl get pods -n apps -l app=frontend-podinfo -o jsonpath='{.items[].metadata.name}')"

# export FRONTEND_NAME=$(kubectl get pods -n apps -l app=frontend-podinfo -o jsonpath='{.items[].metadata.name}')
# kubectl -n apps exec -it ${FRONTEND_NAME} -- sh
# curl backend-podinfo.apps.svc.cluster.local:9898
# while true; do curl backend-podinfo.apps.svc.cluster.local:9898; echo; sleep .5; done
cmd 

TYPE_SPEED=90

pe "cat << EOF > apps/3-podinfo-virtual-services.yaml
apiVersion: appmesh.k8s.aws/v1beta1
kind: VirtualService
metadata:
  name: backend-podinfo.apps.svc.cluster.local
  namespace: apps
spec:
  meshName: apps
  virtualRouter:
    name: backend-podinfo-router
  routes:
    - name: podinfo-route
      http:
        match:
          prefix: /
        action:
          weightedTargets:
            - virtualNodeName: backend-podinfo-v2
              weight: 100
EOF
"

TYPE_SPEED=50

pe "git add -A"

pe 'git commit -m "adding in virtual svc, virtualnode, and apps"'

pe "git push"

pe "git reset --hard HEAD~1"

pe "git push -f"

pe "git log --oneline"