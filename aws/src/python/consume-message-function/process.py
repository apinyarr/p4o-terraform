# import boto3
# import json
from __future__ import print_function

def lambda_handler(event, context):
    for record in event['bot']:
        print("test")
        payload = record["body"]
        print(str(payload))
    # # Create SQS client
    # sqs = boto3.client('sqs')
    # queue_url = 'https://sqs.ap-southeast-1.amazonaws.com/125065023022/demo-dlq'
    # # Receive message from SQS queue
    # response = sqs.receive_message(
    #     QueueUrl=queue_url,
    #     AttributeNames=[
    #         'string'
    #     ],
    #     MaxNumberOfMessages=1,
    #     MessageAttributeNames=[
    #         'All'
    #     ],
    #     VisibilityTimeout=0,
    #     WaitTimeSeconds=0
    # )

    # message = response['Messages'][0]
    # receipt_handle = message['ReceiptHandle']

    # Delete received message from queue
    # sqs.delete_message(
    #     QueueUrl=queue_url,
    #     ReceiptHandle=receipt_handle
    # )
    # print('Received and deleted message: %s' % message)