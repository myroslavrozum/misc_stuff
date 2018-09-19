#src/gke-workout/depmanager/gke/
gcloud deployment-manager deployments create gke-workout --config=./gke_workout.yaml

kubectl create namespace monitoring
kubectl create -f config-map.yaml -n monitoring
kubectl apply -f ./rbak-setup.yaml
kubectl apply -f ./deployment.yaml
kubectl expose deployment prometheus  --type=LoadBalancer --name=prometheus-service

cd ../../build/
gsutil cp gs://gke-workout-scripts/prometheus.yml .
gcloud builds submit --config=./cloudbuild_Dockerfile.yaml

