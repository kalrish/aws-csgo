AWS-based Counter Strike: Global Offensive server
================================================================================

This repository contains code to deploy, provision and manage a _Counter Strike: Global Offensive_ server based on the Amazon Web Services cloud platform.

<p align="center">
<img alt="Counter Strike 1.6 logo" src="img/cs16.svg" height="200px" width="200px" align="middle" />
<img alt="AWS logo" src="img/aws.svg" height="250px" width="250px" align="middle" />
</p>


Deployment
--------------------------------------------------------------------------------

This process should be based on the AWS region closest to the players, which should offer them the lowest latency and therefore a better experience. Nevertheless, pricing differences amongst regions might be a concern, so be sure to check!

 1.  Deploy the stack.
 
     Deploy a new CloudFormation stack based on the `cfn.yaml` template. None of the resources will incur in any costs at this point, except for the NAT instance, which is required by the CodeBuild project to reach the EC2 and SSM services and might be safely stopped when not needed.
 
 2.  Create the key pair.
 
     1.  Create the EC2 key pair, saving the private key.
     
             $  aws --query 'KeyMaterial' --output text ec2 create-key-pair --key-name csgo > ~/.ssh/csgo.pem
     
     2.  Upload the private key to the SSM parameter store.
     
             $  aws ssm put-parameter --name /csgo/ssh-key --type SecureString --value "file://${HOME}/.ssh/csgo.pem"
         
         CodeBuild will retrieve it later to build the AMI. Since it will do so in a safe manner, a separate key pair is not required.
 
 3.  Build the server image.
 
     The installation and configuration of the _Counter Strike: Global Offensive_ server takes some time. To avoid having to repeat that effort needlessly, the process is performed once and saved as an EC2 machine image, which is then used to spawn instances from it.
     
     The build process of the AMI is handled by a CodeBuild project, such that you need only execute the following command:
     
         $  aws codebuild start-build --project-name csgo-ami
     
     Should there not be enough capacity for the default `c5.large` instance type used for the purpose, you may override it as follows:
     
         $  aws codebuild start-build --project-name csgo-ami --environment-variables-override name=INSTANCE_TYPE,type=PLAINTEXT,value=t2.micro
     
     While you wait for the process to complete, continue with the next steps. When it finishes, you can stop the NAT instance.
 
 4.  Upload your secrets.
 
     A couple of keys are needed for the game server to function properly. In order to streamline their management and enable their replacement while keeping them safe, the parameter store is made use of.
     
     -  GSLT
     
         Valve introduced so-called game server login tokens, a kind of hashes associated with an user's account which are used to identify and authenticate public game servers and enable keeping track of them despite IP address changes. You should obtain a new one at the [game server account management page](https://steamcommunity.com/dev/managegameservers) offered by Valve to that end.
         
         Then, upload it to the parameter store:
         
             $  aws ssm put-parameter --overwrite --name /csgo/gslt --type SecureString --value "${GSLT}"
         
         Since the login token is associated with your account, it may be used to impersonate you and thus get you in unexpected trouble. By storing it in an encrypted manner, that danger is reduced.
     
     -  Web API key
     
         The web API key is required to download maps from the workshop. You can generate one for your account at the [web API key generation page](https://steamcommunity.com/dev/apikey), also offered by Valve itself.
         
         Upload it to the parameter store following the same procedure:
         
             $  aws ssm put-parameter --overwrite --name /csgo/web-api-key --type SecureString --value "${WEB_API_KEY}"
         
         The key is also associated with your account, so it must be encrypted as well.
     
     You may update them at any time; server instances will pick up new values automatically when the game server service is restarted. To do so, log into the server instance via SSH and execute the following command:
     
         #  systemctl restart csgo-server.service
     
     Restarting the instance itself will do as well.
 
That's about it. Don't forget to stop the NAT instance when the AMI build finishes. Now on to the fun part!


Usage
--------------------------------------------------------------------------------

Launching the server is made straightforward thanks to the launch template, which CodeBuild updates with the ID of the newly-built AMI. Just execute:

    $  INSTANCE_ID=$(aws --query 'Instances[0].InstanceId' --output text ec2 run-instances --launch-template LaunchTemplateName=csgo-server)

The default instance type is `c5.large`, but a mere `t2.micro` might do, depending on your server configuration and the number of players. It is also useful for testing due to the lower price. Nevertheless, for real use, an instance type with greater compute power, ampler network bandwidth and more reliable performance characteristics will be better suited and offer a better experience.

In order to connect to the instance, either through SSH or with the game client, you will need its IP address. You can retrieve its public IPv4 address using the following command:

    $  INSTANCE_IP=$(aws --query 'Reservations[0].Instances[0].PublicIpAddress' --output text ec2 describe-instances --instance-ids ${INSTANCE_ID})

Alternatively, you may use the DNS name, which is more catchy and will let you match it in your SSH configuration. Retrieve it as follows:

    $  INSTANCE_HOST=$(aws --query 'Reservations[0].Instances[0].PublicDnsName' --output text ec2 describe-instances --instance-ids ${INSTANCE_ID})

To inspect the state of the server, upload your game configuration or perform any kind of maintenance, you can SSH into the instance as follows:

    $  ssh -o StrictHostKeyChecking=no -i ~/.ssh/csgo.pem ubuntu@${INSTANCE_IP}

After you are done playing, stop or terminate the server:

    $  # The instance and its data is preserved, but you will still be charged for the EBS volume usage
    $  aws ec2 stop-instances --instance-ids ${INSTANCE_ID}
    $  # The instance is completely terminated and its EBS volumes destroyed
    $  aws ec2 terminate-instances --instance-ids ${INSTANCE_ID}

Have fun!
