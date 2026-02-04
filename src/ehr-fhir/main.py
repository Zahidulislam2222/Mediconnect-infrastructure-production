import json
import logging
import os
import requests
from google.cloud import spanner
from google.cloud import kms

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
    
    # Audit Log
    logger.info(json.dumps({
        "level": "INFO",
        "message": "EHR Service Invoked",
        "path": path
    }))

    try:
        if path == '/ehr/fhir/patient':
            return handle_fhir_patient(event)
        elif path == '/ehr/sign':
            return handle_digital_signature(event)
        else:
             return {'statusCode': 404, 'headers': HEADERS, 'body': json.dumps({'message': 'Not Found'})}
            
    except Exception as e:
        logger.error(json.dumps({
            "level": "ERROR",
            "message": "EHR Service Error",
            "error": str(e)
        }))
        return {'statusCode': 500, 'headers': HEADERS, 'body': json.dumps({'message': 'Internal Error'})}

def handle_fhir_patient(event):
    # Proxy to Azure Health Data Services
    fhir_service_url = os.environ.get('FHIR_SERVICE_URL')
    access_token = os.environ.get('FHIR_ACCESS_TOKEN') # Use Managed Identity in Prod

    if event.get('httpMethod') == 'GET':
        patient_id = event.get('queryStringParameters', {}).get('id')
        response = requests.get(
            f"{fhir_service_url}/Patient/{patient_id}",
            headers={'Authorization': f'Bearer {access_token}'}
        )
        return {
            'statusCode': response.status_code,
            'headers': HEADERS,
            'body': response.text
        }
    return {'statusCode': 405, 'headers': HEADERS, 'body': json.dumps({'message': 'Method Not Allowed'})}

def handle_digital_signature(event):
    # Sign document using Cloud KMS and store in Spanner
    kms_client = kms.KeyManagementServiceClient()
    spanner_client = spanner.Client()
    instance = spanner_client.instance(os.environ.get('SPANNER_INSTANCE'))
    database = instance.database(os.environ.get('SPANNER_DATABASE'))

    body = json.loads(event.get('body', '{}'))
    document_hash = body.get('hash')
    doctor_id = body.get('doctorId')

    if not document_hash:
        return {'statusCode': 400, 'headers': HEADERS, 'body': json.dumps({'message': 'Missing hash'})}

    # Digital Signature (KMS)
    key_name = os.environ.get('KMS_KEY_NAME')
    sign_response = kms_client.asymmetric_sign(
        request={'name': key_name, 'digest': {'sha256': document_hash.encode('utf-8')}}
    )
    signature = sign_response.signature

    # Store in Spanner
    def insert_signature(transaction):
        transaction.execute_update(
            "INSERT INTO Signatures (DoctorId, DocumentHash, Signature, Timestamp) "
            "VALUES (@doctorId, @hash, @signature, PENDING_COMMIT_TIMESTAMP())",
            params={
                'doctorId': doctor_id,
                'hash': document_hash,
                'signature': signature
            },
            param_types={
                'doctorId': spanner.param_types.STRING,
                'hash': spanner.param_types.STRING,
                'signature': spanner.param_types.BYTES
            }
        )

    database.run_in_transaction(insert_signature)

    return {
        'statusCode': 201,
        'headers': HEADERS,
        'body': json.dumps({'status': 'Signed', 'signature': str(signature)})
    }
