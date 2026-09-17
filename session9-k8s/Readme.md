# Kubernetes Basics

These are my notes from the "Learn Kubernetes Basics" tutorial on the Kubernetes docs site. The tutorial explains how a Kubernetes cluster works and goes through the main features one module at a time. Each module has some background on a concept and then a small hands-on part.

## What the tutorial teaches

- How to deploy a containerized app on a cluster
- How to scale the deployment
- How to update the app to a new version
- How to debug the app

## Why Kubernetes?

Today people expect apps to be up all the time, and developers want to release new versions many times a day. Containers help with this because we can package the app and update it without downtime.

Kubernetes manages those containers for us. It makes sure they run where and when we want and gives them the resources they need. It is open source and ready for production, and it's based on Google's experience running containers plus good ideas from the community.

## The 6 modules

### 1. Create a cluster
A cluster has a control plane that manages everything and nodes that run the apps. For practice we can make a small local cluster with Minikube.
```bash
minikube start
kubectl get nodes
```

### 2. Deploy an app
We create a Deployment, which tells Kubernetes which container image to run and how many copies we want. If a pod or node goes down, Kubernetes replaces it on its own.
```bash
kubectl create deployment kubernetes-bootcamp --image=gcr.io/google-samples/kubernetes-bootcamp:v1
kubectl get deployments
```

### 3. Explore the app
A pod is one or more containers that share storage and an IP address. Pods run on nodes. We can check what's going on with these commands:
```bash
kubectl get pods
kubectl describe pods
kubectl logs <pod-name>
kubectl exec -ti <pod-name> -- bash
```

### 4. Expose the app publicly
Pods can only be reached inside the cluster, and their IPs change when they restart. A Service gives the app a stable address so it can be reached from outside.
```bash
kubectl expose deployment/kubernetes-bootcamp --type=NodePort --port 8080
kubectl get services
```

### 5. Scale the app
We increase or decrease the number of replicas, and the Service spreads traffic across all of them.
```bash
kubectl scale deployments/kubernetes-bootcamp --replicas=4
kubectl get pods -o wide
```

### 6. Update the app
A rolling update replaces old pods with new ones a few at a time, so the app never goes down. If something breaks, we can roll back.
```bash
kubectl set image deployments/kubernetes-bootcamp kubernetes-bootcamp=docker.io/jocatalin/kubernetes-bootcamp:v2
kubectl rollout status deployments/kubernetes-bootcamp
kubectl rollout undo deployments/kubernetes-bootcamp
```

## What I understood

- Kubernetes keeps the app in the state we ask for, so we don't restart things by hand.
- A Deployment manages pods, and a Service makes them reachable.
- Scaling and updating the app are just one command each.

## What's next

The tutorial suggests reading the Learning environment page to learn about practice clusters and how to set one up yourself.

## Resources

- https://kubernetes.io/docs/tutorials/kubernetes-basics/
- https://minikube.sigs.k8s.io/docs/start/
- https://kubernetes.io/docs/concepts/architecture/
- https://github.com/Nency-Ravaliya/Kubernetes
