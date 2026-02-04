import json
import os
import logging
import boto3
from google.cloud import aiplatform

# Setup Logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

HEADERS = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
    'Strict-Transport-Security': 'max-age=31536000; includeSubDomains; preload',
    'X-Content-Type-Options': 'nosniff',
    'Content-Type': 'application/json'
}

def handler(event, context):
    path = event.get('path', '')
    http_method = event.get('httpMethod', '')
    
    # Audit Log
    logger.info(json.dumps({
        "level": "INFO",
        "message": "AI Analysis Invoked",
        "path": path,
        "method": http_method
    }))

    try:
        if path == '/analyze/image' and http_method == 'POST':
            return analyze_image(event)
        elif path == '/analyze/medical' and http_method == 'POST':
            return analyze_medical_imaging(event)
        else:
            return {
                'statusCode': 404,
                'headers': HEADERS,
                'body': json.dumps({'message': 'Not Found'})
            }
    except Exception as e:
        logger.error(json.dumps({
            "level": "ERROR",
            "message": "AI Analysis Error",
            "error": str(e) # Ensure generic error messages if possible, but str(e) is usually safe for system errors
        }))
        return {
            'statusCode': 500,
            'headers': HEADERS,
            'body': json.dumps({'message': 'Internal Server Error'})
        }

def analyze_image(event):
    # AWS Rekognition for Identity Verification / General Image Analysis
    rekognition = boto3.client('rekognition')
    body = json.loads(event.get('body', '{}'))
    bucket = body.get('bucket')
    key = body.get('key')

    if not bucket or not key:
        return {'statusCode': 400, 'headers': HEADERS, 'body': json.dumps({'message': 'Missing bucket or key'})}

    response = rekognition.detect_labels(
        Image={'S3Object': {'Bucket': bucket, 'Name': key}},
        MaxLabels=10
    )

    return {
        'statusCode': 200,
        'headers': HEADERS,
        'body': json.dumps(response['Labels'])
    }

def analyze_medical_imaging(event):
    # GCP Vertex AI for Medical Imaging (Placeholder for custom model)
    # Assumes Vertex AI Endpoint is configured
    project_id = os.environ.get('GCP_PROJECT_ID')
    endpoint_id = os.environ.get('VERTEX_ENDPOINT_ID')
    location = os.environ.get('GCP_REGION', 'us-central1')

    if not project_id or not endpoint_id:
         return {'statusCode': 500, 'headers': HEADERS, 'body': json.dumps({'message': 'Vertex AI Configuration Missing'})}

    aiplatform.init(project=project_id, location=location)
    endpoint = aiplatform.Endpoint(endpoint_id)

    # Simplified prediction call
    # In reality, you'd process the image into the format expected by the model
    body = json.loads(event.get('body', '{}'))
    instances = body.get('instances', [])
    
    prediction = endpoint.predict(instances=instances)

    return {
        'statusCode': 200,
        'headers': HEADERS,
        'body': json.dumps(prediction.predictions)
    }
