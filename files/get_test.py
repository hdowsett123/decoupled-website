import boto3
import json
from boto3.dynamodb.conditions import Key


dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('cloud-resume-challenge')

def test_get_count():
    response = table.query(
        KeyConditionExpression=Key('ID').eq('Count')
        )
    count = response['Items'][0]['Visitors']
    return count

def test_lambda_handler():

    return {
        'statusCode': 200,
        'headers': {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': '*',
            'Access-Control-Allow-Credentials': '*',
            'Content-Type': 'application/json'
        },
        'body': test_get_count()
    }
