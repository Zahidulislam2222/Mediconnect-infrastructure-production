import json
import logging
import os
import boto3
import uuid
from google.cloud import spanner

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
        "message": "Prescription Service Invoked",
        "path": path
    }))

    try:
        if path == '/prescription/create':
            return create_prescription(event)
        else:
             return {'statusCode': 404, 'headers': HEADERS, 'body': json.dumps({'message': 'Not Found'})}
            
    except Exception as e:
        logger.error(json.dumps({
            "level": "ERROR",
            "message": "Prescription Service Error",
            "error": str(e)
        }))
        return {'statusCode': 500, 'headers': HEADERS, 'body': json.dumps({'message': 'Internal Error'})}

def create_prescription(event):
    body = json.loads(event.get('body', '{}'))
    drug_id = body.get('drugId')
    patient_id = body.get('patientId')
    
    # 1. Check Drug Interactions (DynamoDB)
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(os.environ.get('INTERACTION_TABLE_NAME'))
    
    # Simplified interaction check (Mock)
    interaction = table.get_item(Key={'drug1_id': drug_id, 'drug2_id': 'EXISTING_MED_ID'})
    if 'Item' in interaction and interaction['Item'].get('severity') == 'MAJOR':
         return {
             'statusCode': 409,
             'headers': HEADERS,
             'body': json.dumps({'message': 'Major Drug Interaction Detected', 'details': interaction['Item']})
         }
         
    # 2. Store in Cloud Spanner
    spanner_client = spanner.Client()
    instance = spanner_client.instance(os.environ.get('SPANNER_INSTANCE'))
    database = instance.database(os.environ.get('SPANNER_DATABASE'))
    
    prescription_id = str(uuid.uuid4())
    
    def insert_rx(transaction):
        transaction.execute_update(
            "INSERT INTO Prescriptions (PrescriptionId, PatientId, DrugId, CreatedAt) "
            "VALUES (@pid, @patId, @did, PENDING_COMMIT_TIMESTAMP())",
            params={'pid': prescription_id, 'patId': patient_id, 'did': drug_id},
            param_types={
                'pid': spanner.param_types.STRING,
                'patId': spanner.param_types.STRING, 
                'did': spanner.param_types.STRING
            }
        )
    
    database.run_in_transaction(insert_rx)
    
    # 3. Send to Surescripts (Mock)
    # Convert to NCPDP SCRIPT (XML)
    ncpdp_message = f"<Message><NewRx><Drug>{drug_id}</Drug></NewRx></Message>"
    # Post to external API (not implemented)

    return {
        'statusCode': 201,
        'headers': HEADERS,
        'body': json.dumps({'message': 'Prescription Created', 'id': prescription_id})
    }
