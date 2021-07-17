import boto3  
import json

def lambda_handler(event, context):
    sqs = boto3.resource('sqs')
    queue = sqs.get_queue_by_name(QueueName='demo-queue')
    response = queue.send_message(MessageBody=json.dumps(event))
    path = json.dumps(event['rawPath'])
    # if path is not success, generate a number of responses for triggering Dead-letter Queue
    if path.find("success") < 0:
        # Force publish message to dlq
        response = queue.send_message(MessageBody=json.dumps(event))
        response = queue.send_message(MessageBody=json.dumps(event))
        response = queue.send_message(MessageBody=json.dumps(event))
        response = queue.send_message(MessageBody=json.dumps(event))
        sqs2 = boto3.client('sqs')
        # queue_url = 'https://sqs.ap-southeast-1.amazonaws.com/125065023022/demo-queue'
        queue_url = sqs2.get_queue_url(
            QueueName='demo-queue',
            QueueOwnerAWSAccountId=boto3.client('sts').get_caller_identity()['Account']
        )['QueueUrl']
        # Receive message from SQS queue
        response = sqs2.receive_message(
            QueueUrl=queue_url,
            AttributeNames=[
                'string'
            ],
            MaxNumberOfMessages=10,
            MessageAttributeNames=[
                'All'
            ],
            VisibilityTimeout=0,
            WaitTimeSeconds=5
        )
    return path