import boto3  
import json

def lambda_handler(event, context):

    sqs = boto3.resource('sqs')

    queue = sqs.get_queue_by_name(QueueName='demo-queue')
    # queue = sqs.Queue(url='https://sqs.ap-southeast-1.amazonaws.com/125065023022/demo-queue')

    response = queue.send_message(MessageBody=json.dumps(event))

    return event['pathParameters']['param1']