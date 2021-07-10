import boto3  
import json

def lambda_handler(event, context):

    # sqs = boto3.resource('sqs')

    sqs = boto3.client('sqs', region_name="ap-southeast-1")

    queue = sqs.get_queue_by_name(QueueName='demo-queue')

    response = queue.send_message(MessageBody=json.dumps(event))