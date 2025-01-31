#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the "Software"), to deal in the Software
# without restriction, including without limitation the rights to use, copy, modify,
# merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

source /etc/parallelcluster/cfnconfig
cfn_fsx_fs_id=$(cat /etc/chef/dna.json | grep \"cfn_fsx_fs_id\" | awk '{print $2}' | sed "s/\",//g;s/\"//g")
master_instance_id=$(ec2-metadata -i | awk '{print $2}')
cfn_max_queue_size=$(aws cloudformation describe-stacks --stack-name $stack_name --region $cfn_region | jq -r '.Stacks[0].Parameters | map(select(.ParameterKey == "MaxSize"))[0].ParameterValue')
monitoring_dir_name="monitoring"
monitoring_home="${SHARED_FS_DIR}/${monitoring_dir_name}"
chef_dna="/etc/chef/dna.json"
s3_bucket=$(echo $cfn_postinstall | sed "s/s3:\/\///g;s/\/.*//")
grafana_password=$(aws secretsmanager get-secret-value --secret-id "${stack_name}" --query SecretString --output text --region "${cfn_region}")
NICE_ROOT=$(jq --arg default "${SHARED_FS_DIR}/nice" -r '.post_install.enginframe | if has("nice_root") then .nice_root else $default end' "${dna_json}")


set -x
set -e

installPreReq() {
    yum -y install docker golang-bin 
    service docker start
    chkconfig docker on
    usermod -a -G docker $cfn_cluster_user

    #to be replaced with yum -y install docker-compose as the repository problem is fixed
    curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
}

saveClusterConfigLocally(){
    
	cluster_s3_bucket=$(cat "${chef_dna}" | grep \"cluster_s3_bucket\" | awk '{print $2}' | sed "s/\",//g;s/\"//g")
	cluster_config_s3_key=$(cat "${chef_dna}" | grep \"cluster_config_s3_key\" | awk '{print $2}' | sed "s/\",//g;s/\"//g")
	cluster_config_version=$(cat "${chef_dna}" | grep \"cluster_config_version\" | awk '{print $2}' | sed "s/\",//g;s/\"//g")
	log_group_names="\/aws\/parallelcluster\/$(echo ${stack_name} | cut -d "-" -f2-)"
	
	mkdir -p "${monitoring_home}/parallelcluster"
	aws s3api get-object --bucket $cluster_s3_bucket --key $cluster_config_s3_key --region $cfn_region --version-id $cluster_config_version "${monitoring_home}/parallelcluster/cluster-config.json"
}

installMonitoring(){
    
    aws s3 cp --recursive "${post_install_base}/monitoring" "${monitoring_home}" --region "${cfn_region}" || exit 1
	chown $cfn_cluster_user:$cfn_cluster_user -R "${monitoring_home}"
	chmod +x ${monitoring_home}/custom-metrics/*

	cp -rp ${monitoring_home}/custom-metrics/* /usr/local/bin/
	mv -f "${monitoring_home}/prometheus-slurm-exporter/slurm_exporter.service" /etc/systemd/system/
	
	cp -rp ${monitoring_home}/www/* "${NICE_ROOT}/enginframe/conf/tomcat/webapps/ROOT/"
}



configureMonitoring() {

	 	(crontab -l -u $cfn_cluster_user; echo "*/1 * * * * /usr/local/bin/1m-cost-metrics.sh") | crontab -u $cfn_cluster_user -
		(crontab -l -u $cfn_cluster_user; echo "*/60 * * * * /usr/local/bin/1h-cost-metrics.sh") | crontab -u $cfn_cluster_user - 

		# replace tokens 
		sed -i "s/_S3_BUCKET_/${s3_bucket}/g"               	"${monitoring_home}/grafana/dashboards/ParallelCluster.json"
		sed -i "s/__INSTANCE_ID__/${master_instance_id}/g"  	"${monitoring_home}/grafana/dashboards/ParallelCluster.json"
		sed -i "s/__FSX_ID__/${cfn_fsx_fs_id}/g"            	"${monitoring_home}/grafana/dashboards/ParallelCluster.json"
		sed -i "s/__AWS_REGION__/${cfn_region}/g"           	"${monitoring_home}/grafana/dashboards/ParallelCluster.json"

		sed -i "s/__AWS_REGION__/${cfn_region}/g"           	"${monitoring_home}/grafana/dashboards/logs.json"
		sed -i "s/__LOG_GROUP__NAMES__/${log_group_names}/g"    "${monitoring_home}/grafana/dashboards/logs.json"

		sed -i "s/__Application__/${stack_name}/g"          	"${monitoring_home}/prometheus/prometheus.yml"

		sed -i "s/__INSTANCE_ID__/${master_instance_id}/g"  	"${monitoring_home}/grafana/dashboards/master-node-details.json"
		sed -i "s/__INSTANCE_ID__/${master_instance_id}/g"  	"${monitoring_home}/grafana/dashboards/compute-node-list.json"
		sed -i "s/__INSTANCE_ID__/${master_instance_id}/g"  	"${monitoring_home}/grafana/dashboards/compute-node-details.json"

		sed -i "s~__MONITORING_DIR__~${monitoring_home}~g"  	"${monitoring_home}/docker-compose/docker-compose.master.yml"
		sed -i "s~__GRAFANA_PASSWORD__~${grafana_password}~g"  	"${monitoring_home}/docker-compose/docker-compose.master.yml"
		

		# Download and build prometheus-slurm-exporter 
		##### Plese note this software package is under GPLv3 License #####
		# More info here: https://github.com/vpenso/prometheus-slurm-exporter/blob/master/LICENSE
		cd "${monitoring_home}"
		#FIXME: temporary
		rm -rf prometheus-slurm-exporter 
		git clone https://github.com/vpenso/prometheus-slurm-exporter.git
		cd prometheus-slurm-exporter
		sed -i 's/NodeList,AllocMem,Memory,CPUsState,StateLong/NodeList: ,AllocMem: ,Memory: ,CPUsState: ,StateLong:/' node.go
		GOPATH=/root/go-modules-cache HOME=/root go mod download
		GOPATH=/root/go-modules-cache HOME=/root go build
		mv -f "${monitoring_home}/prometheus-slurm-exporter/prometheus-slurm-exporter" /usr/bin/prometheus-slurm-exporter
}


startMonitoringDaemons() {

    /usr/local/bin/docker-compose --env-file /etc/parallelcluster/cfnconfig -f "${monitoring_home}/docker-compose/docker-compose.master.yml" -p monitoring-master up -d
    systemctl daemon-reload
	systemctl enable slurm_exporter
	systemctl start slurm_exporter

}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 40.install.monitoring.master.sh: START" >&2
    installPreReq
    saveClusterConfigLocally
    installMonitoring
    configureMonitoring
    startMonitoringDaemons
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 40.install.monitoring.master.sh: STOP" >&2
}

main "$@"