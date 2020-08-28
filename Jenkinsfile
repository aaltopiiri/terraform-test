pipeline {

agent any

  stages {

    stage('TF Plan') {
      steps {
          sh 'terraform init'
          sh 'terraform plan -var-file=variables.tfvars -out myplan'
      }      
    }


    stage('TF Apply') {
      steps {
          sh 'terraform apply -var-file=variables.tfvars -input=false myplan --auto-approve'
      }
    }
  } 
}