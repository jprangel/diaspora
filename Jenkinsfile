AWS_REGION = "us-east-1"
DEV_ECS_CLUSTER = "dev-cluster"
DEV_ECS_SERVICE = "dev-diaspora"
DEV_ECS_TASK = DEV_ECS_SERVICE
QA_ECS_CLUSTER = "qa-cluster"
QA_ECS_SERVICE = "qa-diaspora"
QA_ECS_TASK = QA_ECS_SERVICE
ECR_IMAGE = ".dkr.ecr.us-east-1.amazonaws.com/diaspora"
SLACK_COLOR_GOOD = '#3EB991'
GITHUB_OWNER = "jpolarix"
GITHUB_REPO = "diaspora"

/**
 * Pipeline Properties
 *
 * githubPullRequest docs at https://github.com/jenkinsci/ghprb-plugin
 * https://github.com/jenkinsci/ghprb-plugin/issues/536
 */
properties([
        [$class       : 'GithubProjectProperty',
         displayName  : 'Diaspora deploy project',
         projectUrlStr: 'https://github.com/jpolarix/diaspora/'],
        pipelineTriggers([
                githubPush()
        ])
])

/**
 * Helper Methods
 */
 def dockerPushImages(VERSION) {
     sh "docker push ${ECR_IMAGE}:${VERSION}"
 }

 def awsServiceRunningCount(String serviceName, String ecs_cluster) {
     return sh([
             script      : "aws ecs describe-services --region ${AWS_REGION} --cluster ${ecs_cluster} --services ${serviceName} | jq '.services[] | .deployments[] | .runningCount' -r",
             returnStdout: true
     ]).trim().toInteger()
 }

 def isAWSServiceRunning(String serviceName, String ecs_cluster) {
     return awsServiceRunningCount(serviceName, ecs_cluster) > 0
 }

 def stopAWSService(String serviceName, String ecs_cluster) {
     sh "aws ecs update-service --region ${AWS_REGION} --cluster ${ecs_cluster} --service ${serviceName} --desired-count 0"
     TASK_ARN = sh([
             script      : "aws ecs list-tasks --region ${AWS_REGION} --cluster ${ecs_cluster} --family ${DEV_ECS_TASK}  --output text --query taskArns[]",
             returnStdout: true
     ]).trim()
     sh "aws ecs stop-task --region ${AWS_REGION} --task ${TASK_ARN} --cluster ${ecs_cluster}"
 }

 def startAWSService(String serviceName, Integer desiredCount = 1, String ecs_cluster) {
     sh "aws ecs update-service --region ${AWS_REGION} --cluster ${ecs_cluster} --service ${serviceName} --desired-count ${desiredCount}"
 }

 def updateTaskImageVersionAWSService(String taskName, String version) {
     sh "aws ecs describe-task-definition --region ${AWS_REGION} --task-definition ${taskName} | " +
             "jq '.taskDefinition.containerDefinitions[].image = \"${ECR_IMAGE}:${version}\" | " +
             ".taskDefinition | " +
             "{family:.family," +
             " taskRoleArn:.taskRoleArn," +
             " networkMode:.networkMode," +
             " containerDefinitions:.containerDefinitions," +
             " volumes:.volumes," +
             " placementConstraints:.placementConstraints}' >| new-task-def.json"
     sh "aws ecs register-task-definition --region ${AWS_REGION} --cli-input-json file://new-task-def.json"
 }

 def updateDesiredCountAWSService(String serviceName) {
     echo "Stopping service [${serviceName}]"
     stopAWSService(serviceName, DEV_ECS_CLUSTER)
     timeout(time: 120, unit: 'SECONDS') {
         waitUntil {
             echo "Still waiting for service [${serviceName}] to stop"
             return !isAWSServiceRunning(serviceName, DEV_ECS_CLUSTER)
         }
     }
     echo "Service [${serviceName}] stopped, starting new version"
     startAWSService(serviceName, DEV_ECS_CLUSTER)
     timeout(time: 120, unit: 'SECONDS') {
         waitUntil {
             echo "Still waiting for service [${serviceName}] to start"
             return isAWSServiceRunning(serviceName, DEV_ECS_CLUSTER)
         }
     }
     echo "Service [${serviceName}] started succefully"
 }

 def updateTaskVersionAWSService(String serviceName, String version) {
     echo "Updating task [${QA_ECS_TASK}]"
     updateTaskImageVersionAWSService(QA_ECS_TASK, version)

     echo "Updating service [${QA_ECS_SERVICE}]"
     //With no revision at the task parameter it will be attached the last avaible
     sh "aws ecs update-service --region ${AWS_REGION} --cluster ${QA_ECS_CLUSTER} --service ${QA_ECS_SERVICE} --task-definition ${QA_ECS_TASK}"
 }

/**
 * Pipeline Steps
 */
timestamps {
    node {
        try {
            stage('checkout') {
                checkout scm
            }

            // Global docker timeout
            timeout(time: 35, unit: 'MINUTES') {
              // Verify if this version is tagged
              String git_tag = sh([returnStdout: true, script: 'git tag -l --points-at HEAD']).trim()

              if (git_tag == env.BRANCH_NAME) {
                  stage("Promote to QA Environment") {
                      sh "\$(aws ecr get-login --no-include-email --region ${AWS_REGION})"
                      sh "docker pull ${ECR_IMAGE}:latest"
                      sh "docker tag ${ECR_IMAGE}:latest ${ECR_IMAGE}:${git_tag}"
                      dockerPushImages(git_tag)
                      updateTaskVersionAWSService(QA_ECS_SERVICE, git_tag)
                          releaseBody = sh([returnStdout: true,
                              script      :"cat tag.tmp | jq '.body'"]).trim()
                      }
          		    slackSend ([color: "${SLACK_COLOR_GOOD}",
                            channel: '#qa-deploy',
                            message: "*SUCCESS:* Job ${env.JOB_NAME} build ${env.BUILD_NUMBER}\n Description of the Release: ${releaseBody}\n More info at: ${env.BUILD_URL}"
                          ])

                  }

              } else {
                    docker.image('openjdk:8u151-jdk').inside("-e GRADLE_USER_HOME=.gradle") {
                        stage('check java') {
                            sh "java -version"
                        }

                        stage('clean') {
                        }

                        stage('unit tests') {
                        }

                        stage('packaging') {
                        }

                        stage('quality analysis') {
                            }
                        }
                    }
                }

                //only run these steps on the master branch
                if (env.BRANCH_NAME == 'master') {
                    stage('Build Docker Image and Publish to ECR') {
                        sh "\$(aws ecr get-login --no-include-email --region ${AWS_REGION})"
                        sh "./gradlew buildDocker -x test --no-daemon"
                    }

                    stage("Deploy to DEV Environment") {
                        dockerPushImages('latest')
                        updateDesiredCountAWSService(DEV_ECS_SERVICE)
                    }
		    stage{"Alert Deploy")
			 slackSend ([color: "${SLACK_COLOR_GOOD}",
                            	channel: '#dev-deploy',
                            	message: "*SUCCESS:* Job ${env.JOB_NAME} build ${env.BUILD_NUMBER}\n Description of the Release: ${releaseBody}\n More info at: ${env.BUILD_URL}"])
                }
            }

        } catch (ex) {
            slackSend([channel: '#jenkins-fail',
                       color  : 'danger',
                       message: "*Build ${currentBuild.result ?: 'FAILED'}:* ${env.JOB_NAME} _#${env.BUILD_NUMBER}_.\nMore details at ${env.BUILD_URL}"
            ])

            throw ex
        } finally {
            timeout(time: 3, unit: 'MINUTES') {
                stage('cleanup') {
                    sh 'docker rm -fv $(docker ps -aq) 2> /dev/null || true'
                    sh 'docker rmi $(docker images -q -f dangling=true) 2> /dev/null || true'
                    cleanWs()
                }
            }
        }
    }
}
