wait_for_resource () {
  resource=$1
  namespace=$2
  while [ true ]
  do
    kubectl wait $resource --for condition=available --timeout=30s -n $namespace
    if [ "$?" -ne "0" ]
    then
      # 'kubectl wait' will error out if the namespace doesn't yet exist, or if the resource hasn't been created yet
      echo "Waiting for $resource in $namespace to come up"
      sleep 3
    else
      break
    fi
  done
}


minikube addons enable ingress
# After the addon is enabled, please run "minikube tunnel" and your ingress resources would be available at "127.0.0.1"
# Question:  is that step needed?

kubectl apply -f https://raw.githubusercontent.com/operator-framework/operator-lifecycle-manager/master/deploy/upstream/quickstart/crds.yaml

crds=("catalogsources.operators.coreos.com" \
  "clusterserviceversions.operators.coreos.com" \
  "installplans.operators.coreos.com" \
  "operatorconditions.operators.coreos.com"\
  "operatorgroups.operators.coreos.com"\
  "operators.operators.coreos.com" \
  "subscriptions.operators.coreos.com")
for index in "${!crds[@]}"
do
  for counter in {0..10}
  do
    crd=${crds[$index]}
    kubectl get crd ${crd}
    if [ "$?" -eq "0" ]
    then
      break
    else
      sleep 1
    fi
  done
done


kubectl apply -f https://raw.githubusercontent.com/operator-framework/operator-lifecycle-manager/master/deploy/upstream/quickstart/olm.yaml

wait_for_resource deployment/catalog-operator olm
wait_for_resource deployment/olm-operator olm
wait_for_resource deployment/packageserver olm

kubectl apply -f https://raw.githubusercontent.com/konveyor/tackle2-operator/main/tackle-k8s.yaml
# Need to wait for namespace and operator to be deployed

wait_for_resource deployment/tackle-operator konveyor-tackle

cat << EOF | kubectl apply -f -
kind: Tackle
apiVersion: tackle.konveyor.io/v1alpha1
metadata:
  name: tackle
  namespace: konveyor-tackle
spec:
  feature_auth_required: false
EOF

wait_for_resource deployment/tackle-hub konveyor-tackle
wait_for_resource deployment/tackle-pathfinder konveyor-tackle
wait_for_resource deployment/tackle-pathfinder-postgresql konveyor-tackle
wait_for_resource deployment/tackle-ui konveyor-tackle

external_ip=""
while [[ -z $external_ip ]]
do
  echo "Waiting for end point..."
  external_ip=$(kubectl get ingress tackle --template="{{range.status.loadBalancer.ingress}}{{.ip}}{{end}}" -n konveyor-tackle);[[ -z $external_ip ]] &&
  echo $external_ip;
  sleep 10;
done

echo "End point ready:" &&
echo $external_ip;
export endpoint=$(minikube ip);








