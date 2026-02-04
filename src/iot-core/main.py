import json
import base64
import logging
import numpy as np
from scipy import stats

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    # Process Kinesis Stream Records
    records = event.get('Records', [])
    
    heart_rates = []
    
    for record in records:
        try:
            # Kinesis data is base64 encoded
            payload = base64.b64decode(record['kinesis']['data']).decode('utf-8')
            data = json.loads(payload)
            
            if 'heart_rate' in data:
                heart_rates.append(data['heart_rate'])
                
            logger.info(json.dumps({
                "level": "INFO",
                "message": "Processed IoT Record",
                "deviceId": data.get('deviceId') # Safe to log device ID
            }))
            
        except Exception as e:
            logger.error(json.dumps({
                "level": "ERROR",
                "message": "Error processing record",
                "error": str(e)
            }))
    
    if not heart_rates:
        return {'status': 'No Data'}

    # Z-Score Anomaly Detection
    data_np = np.array(heart_rates)
    z_scores = stats.zscore(data_np)
    
    anomalies = []
    threshold = 3
    
    for i, z in enumerate(z_scores):
        if np.abs(z) > threshold:
            anomalies.append({
                "index": i,
                "value": heart_rates[i],
                "z_score": z
            })
            
    if anomalies:
        logger.warning(json.dumps({
            "level": "WARNING",
            "message": "Anomalies Detected",
            "count": len(anomalies),
            "anomalies": anomalies 
        }))
        # In a real system, trigger SNS alert here
        
    return {
        'status': 'Processed',
        'records_count': len(records),
        'anomalies_detected': len(anomalies)
    }
