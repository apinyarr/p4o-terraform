import json
import boto3

def lambda_handler(event, context):
    # kinesis firehose stream name in aws
    STREAM_NAME = "terraform-kinesis-firehose-test-stream"
    kinesis_client = boto3.client('firehose')
    for record in event['Records']:
        print("new record")
        payload = record["body"]
        print(str(payload))
        try:
            # write payload to the Delivery stream
            kinesis_client.put_record(
                DeliveryStreamName=STREAM_NAME,
                Record={'Data': json.dumps(payload)}
            )
        except ClientError as e:
            logging.error(e)
            exit(1)