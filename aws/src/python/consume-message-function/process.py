import boto3
import json

def lambda_handler(event, context):
    # Create SQS client
    sqs = boto3.client('sqs')
    queue_url = 'https://sqs.ap-southeast-1.amazonaws.com/125065023022/demo-dlq'
    # Receive message from SQS queue
    response = sqs.receive_message(
        QueueUrl=queue_url,
        AttributeNames=[
            'string'
        ],
        MaxNumberOfMessages=1,
        MessageAttributeNames=[
            'All'
        ],
        VisibilityTimeout=0,
        WaitTimeSeconds=0
    )

    # message = response['Messages'][0]
    # receipt_handle = message['ReceiptHandle']

    # Delete received message from queue
    # sqs.delete_message(
    #     QueueUrl=queue_url,
    #     ReceiptHandle=receipt_handle
    # )
    # print('Received and deleted message: %s' % message)