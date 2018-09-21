cd ~/src/gke-workout/depmanager/gke/
gcloud deployment-manager deployments create gke-workout --config=./gke_workout.yaml

gcloud container clusters get-credentials gke-workout-cluster --zone us-east4-c --project sandbox-217104
kubectl create namespace monitoring
kubectl create -f kubeconfigs/config-map.yaml -n monitoring

ACCOUNT='Myroslav.Rozum@gmail.com'
kubectl create clusterrolebinding owner-cluster-admin-binding     --clusterrole cluster-admin     --user $ACCOUNT
kubectl apply -f kubeconfigs/rbac-setup.yaml

kubectl apply -f kubeconfigs//deployment.yaml

cd ../../build/
gcloud builds submit --config=./cloudbuild_Dockerfile.yaml

kubectl expose deployment prometheus-deployment --type=LoadBalancer --port=80 --target-port=9090 --name=prometheus-service --namespace=monitoring

