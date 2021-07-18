### How to run this terraform ?
<br/>

**Switch to terraform path**
> cd aws

**Run the Terraform**

1. Initail

> terraform init

*result*
> Terraform has been successfully initialized!

2. Plan

> terraform plan

*result*
> Plan: 37 to add, 0 to change, 0 to destroy.

3. Apply

> terraform apply
>> Enter a value: yes

*result*
> Apply complete! Resources: 37 added, 0 changed, 0 destroyed.

---

**Verify resource created in AWS console**

- **IAM Roles** 5 roles have been created

1. p4o-apigw
2. p4o-firehose
3. p4o-glue
4. p4o-lambda-consumer
5. p4o-lambda-producer

- **API Gateway** "prd-http" api has been created

*Remark* copy the Invoke URL for update in Postman Environments configuration

- **Lambda** 2 lambda functions has been created

1. publish-messages-function
2. consume-messages-function

- **CloudWatch** 4 log groups have been created

1. /aws-glue/crawlers (after crawler job has been triggered)
2. /aws/apigw/accesslog
3. /aws/lambda/consume-messages-function
4. /aws/lambda/publish-messages-function

- **Simple Queue Service** 2 queues have been created

1. demo-dlq
2. demo-queue

- **Kinesis** "terraform-kinesis-firehose-test-stream" has been created in the Delivery Streams menu

- **S3** "p4o-s3-bucket" has been created

- **Glue** 2 resources have been created

1. database "my-glue-catalog-database"
2. crawler "my-glue-crawler"

*Logical diagram*

(users:postman) => (API Gateway) => (Producer Lambda) => (SQS) => (Consumer Lambda) => (Kinesis Firehose) => (S3) => (Glue Scrawler) => (Glue database)

---

### How to test using Postman ?
<br/>

1. Import Postman environment from "postman" path

> aws-api-caller.postman_environment.json

2. Import Postman collection from "postman" path

> p4o-apis.postman_collection.json

3. Update **apigw_url** variable in the "aws-api-caller" environment the Save

*For example*

| VARIABLE | INITIAL VALUE | CURRENT VALUE |

| apigw_url | https://osgm1cwg99.execute-api.ap-southeast-1.amazonaws.com | https://osgm1cwg99.execute-api.ap-southeast-1.amazonaws.com |

*caution* remove '/' after the url, if any

4. Select **p4o-api-success** under p4o-apis in the Collections menu and click Send (please ensure that you have chosen "aws-api-caller" environment)

*result*
> /success

*Consequent* Log will be create in CloudWatch, producer function lambda has been run, message has been write to the demo-queue

5. Select **p4o-api-failure** under p4o-apis in the Collections menu and click Send

*result*
> /failure

*Consequent* Log will be create in CloudWatch, producer function lambda has been run, message has been write to the demo-queue, massage has been moved to dlq-queue because messages more than MaxRecieveCount, consumer function lambda read messages and write to kinesis firehose delivery stream, message write to s3, glue crawler run to create catalog database once triggered

*Remark* 
- It takes several minutes until Firehose write payloads to S3.
- Crawler will run at 5 minutes after past the hour.