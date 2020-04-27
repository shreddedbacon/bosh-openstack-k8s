#!/bin/bash

kubectl apply -f 01-namespace.yml
kubectl apply -f 02-datasources.yml
kubectl apply -f 03-deployment.yml
kubectl apply -f 04-service.yml
kubectl apply -f 05-ingress.yml
