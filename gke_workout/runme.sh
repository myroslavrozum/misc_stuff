cd ~/src/gke-workout/gke/
gcloud deployment-manager deployments create gke-workout --config=./gke_workout.yaml

gcloud container clusters get-credentials gke-workout-cluster --zone us-east4-c --project sandbox-217104
kubectl create namespace monitoring

ACCOUNT='Myroslav.Rozum@gmail.com'
kubectl create clusterrolebinding owner-cluster-admin-binding     --clusterrole cluster-admin     --user $ACCOUNT
kubectl apply -f kubeconfigs/rbac-setup.yaml

kubectl create -f kubeconfigs/config-map.yaml -n monitoring
kubectl apply -f kubeconfigs/deployment.yaml
kubectl apply -f kubeconfigs/graphana_deployment.yaml
kubectl create namespace fah
kubectl apply -f kubeconfigs/fah_deployment.yaml

#SERVICEACCOUNT='serviceAccount:xxx@cloudbuild.gserviceaccount.com'

gcloud projects add-iam-policy-binding $GOOGLE_CLOUD_PROJECT \
    --member="$SERVICEACCOUNT" \
    --role='roles/container.developer'

gcloud projects add-iam-policy-binding $GOOGLE_CLOUD_PROJECT \
    --member="$SERVICEACCOUNT" \
    --role='roles/storage.objectCreator'


cd ../build/
gcloud builds submit --config=./cloudbuild_Dockerfile.yaml

kubectl expose deployment prometheus-deployment --type=LoadBalancer --port=80 --target-port=9090 --name=prometheus-service --namespace=monitoring
kubectl expose deployment graphana --type=LoadBalancer --port=80 --target-port=3000 --name=graphana-service --namespace=monitoring

