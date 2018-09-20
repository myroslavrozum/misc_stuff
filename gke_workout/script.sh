#cd src/gke-workout/depmanager/gke/
gcloud deployment-manager deployments create gke-workout --config=./gke_workout.yaml

kubectl create namespace monitoring
kubectl create -f config-map.yaml -n monitoring

ACCOUNT='Myroslav.Rozum@gmail.com'
kubectl create clusterrolebinding owner-cluster-admin-binding     --clusterrole cluster-admin     --user $ACCOUNT
kubectl apply -f ./rbac-setup.yaml

kubectl apply -f ./deployment.yaml
kubectl expose deployment prometheus-deployment --type=LoadBalancer --port=80 --target-port=9090 --name=prometheus-service --namespace=monitoring

cd ../../build/
gcloud builds submit --config=./cloudbuild_Dockerfile.yaml

