def tfCmd(String command, String options = '') {
	ACCESS = "export AWS_PROFILE=${PROFILE} && export TF_ENV_profile=${PROFILE}"
	sh ("cd $WORKSPACE && ${ACCESS} && terraform init") // main
	sh ("cd $WORKSPACE && terraform workspace select ${ENV_NAME} || terraform workspace new ${ENV_NAME}")
	sh ("echo ${command} ${options}") 
    sh ("cd $WORKSPACE && ${ACCESS} && terraform init && terraform ${command} ${options} && terraform show -no-color > show-${ENV_NAME}.txt")
}

pipeline {
  agent any

	environment {
		AWS_REGION = "us-east-1"
		PROFILE = "${params.PROFILE}"
		ACTION = "${params.ACTION}"
		DOMAIN_NAME = "${params.DOMAIN_NAME}"
		PROJECT_DIR = "terraform"
  }
	options {
        buildDiscarder(logRotator(numToKeepStr: '30'))
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
  }
	parameters {
		string (name: 'ENV_NAME',
			   description: 'Environment name')
		string (name: 'DOMAIN_NAME',
			   description: 'Domain name')	   
		choice (name: 'ACTION',
				choices: [ 'plan', 'apply', 'destroy'],
				description: 'Run terraform plan / apply / destroy')
		choice (name: 'PROFILE',
				choices: ['lg', 'cd', 'tvp', 'terraform'],
			   description: 'Target aws profile')
		booleanParam (name: 'is_MX',
		       defaultValue:  'false',
			   description: 'Option to create MX-records')			
 		booleanParam (name: 'is_ALB',
		       defaultValue:  'false',
			   description: 'Option to create records for ALB/ELB')	
		string (name: 'ALB_ZONE_ID_US',
			   defaultValue:  '', 	
			   description: 'Load balancer name in region US')
		string (name: 'ALB_ZONE_ID_EU',
		       defaultValue:  '',
			   description: 'Load balancer name in region EU')
		string (name: 'ALB_ZONE_ID_AP',
		       defaultValue:  '',
			   description: 'Load balancer name in region AP')	
 		booleanParam (name: 'no_ALB',
		       defaultValue:  'false',
			   description: 'Option to create ALB/ELB')		
    }
	stages {
		stage('Checkout & Environment Prep'){
			steps {
				script {
					wrap([$class: 'AnsiColorBuildWrapper', colorMapName: 'xterm'])  {8
							try {
								echo "Setting up Terraform"
								def tfHome = tool name: 'terraform-0.13.2',
									type: 'org.jenkinsci.plugins.terraform.TerraformInstallation'
									env.PATH = "${tfHome}:${env.PATH}"
									currentBuild.displayName += "[$AWS_REGION]::[$ACTION]"
									sh("""
										export AWS_PROFILE=${PROFILE}
										export TF_ENV_profile=${PROFILE}
										mkdir -p /tmp/jenkins/.terraform.d/plugins/macos
									""")
									tfCmd('version')
							} catch (ex) {
                                                                echo 'Err: Incremental Build failed with Error: ' + ex.toString()
								currentBuild.result = "UNSTABLE"
							}
					}
				}
			}
		}		
		stage('terraform plan') {
			when { anyOf
					{
						environment name: 'ACTION', value: 'plan';
						environment name: 'ACTION', value: 'apply'
					}
				}
			steps {
				dir("${PROJECT_DIR}") {
					script {
						wrap([$class: 'AnsiColorBuildWrapper', colorMapName: 'xterm']) {

								try {
									tfCmd('plan', '-var profile="${PROFILE}" -var workspace="${ENV_NAME}" -var zone_name="${DOMAIN_NAME}" -var is_mx="${is_MX}" -var is_alb="${is_ALB}" -var elb_us_zone_id="${ALB_ZONE_ID_US}" -var elb_eu_zone_id="${ALB_ZONE_ID_EU}" -var elb_ap_zone_id="${ALB_ZONE_ID_AP}" -var no_alb="${no_ALB}" -lock=false -detailed-exitcode -out=tfplan')
								} catch (ex) {
									if (ex == 2 && "${ACTION}" == 'apply') {
										currentBuild.result = "UNSTABLE"
									} else if (ex == 2 && "${ACTION}" == 'plan') {
										echo "Update found in plan tfplan"
									} else {
										echo "Try running terraform again in debug mode"
									}

							}
						}
					}
				}
			}
		}
		stage('terraform apply') {
			when { anyOf
					{
						environment name: 'ACTION', value: 'apply'
					}
				}
			steps {
				dir("${PROJECT_DIR}") {
					script {
						wrap([$class: 'AnsiColorBuildWrapper', colorMapName: 'xterm']) {

								try {
									tfCmd('apply', '-lock=false tfplan')
								} catch (ex) {
                  currentBuild.result = "UNSTABLE"
								}
							}
					}
				}
			}

		}
		stage('terraform destroy') {    
			when { anyOf
					{
						environment name: 'ACTION', value: 'destroy';
					}
				}
			steps {
				script {
					def IS_APPROVED = input(
						message: "Destroy ${ENV_NAME} !?!",
						ok: "Yes",
						parameters: [
							string(name: 'IS_APPROVED', defaultValue: 'No', description: 'Think again!!!')
						]
					)
					if (IS_APPROVED != 'Yes') {
						currentBuild.result = "ABORTED"
						error "User cancelled"
					}
				}
				dir("${PROJECT_DIR}") {
					script {
						wrap([$class: 'AnsiColorBuildWrapper', colorMapName: 'xterm']) {
								try {
									tfCmd('destroy', '-var profile="${PROFILE}" -var zone_name="${DOMAIN_NAME}" -var is_mx="${is_MX}" -var is_alb="${is_ALB}" -var elb_us_zone_id="${ALB_ZONE_ID_US}" -var elb_eu_zone_id="${ALB_ZONE_ID_EU}" -var elb_ap_zone_id="${ALB_ZONE_ID_AP}" -var no_alb="${no_ALB}" -lock=false -auto-approve')
								} catch (ex) {
									currentBuild.result = "UNSTABLE"
								}
						}
					}
				}
			}
		}	
  	}
}