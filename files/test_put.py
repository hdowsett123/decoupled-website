import boto3
import json
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('cloud-resume-challenge')


def test_lambda_handler():
    response = table.update_item(
        Key={
            'ID': 'Count'
        },
        UpdateExpression='ADD ' + 'Visitors' + ' :incr',
        ExpressionAttributeValues={
            ':incr': 1
        },
        ReturnValues="UPDATED_NEW"
    )

    return {
        'statusCode': 200,
        'headers': {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': '*',
            'Access-Control-Allow-Credentials': '*',
            'Content-Type': 'application/json'
        }
    }
