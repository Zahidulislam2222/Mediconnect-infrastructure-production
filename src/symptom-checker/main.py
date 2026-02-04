import os
import json
import logging
import openai

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
    # Azure OpenAI Configuration
    openai.api_type = "azure"
    openai.api_base = os.environ.get("AZURE_OPENAI_ENDPOINT")
    openai.api_version = "2023-05-15"
    openai.api_key = os.environ.get("AZURE_OPENAI_KEY")
    deployment_name = os.environ.get("AZURE_DEPLOYMENT_NAME", "gpt-4")

    # Audit Log
    logger.info(json.dumps({
        "level": "INFO",
        "message": "Symptom Checker Invoked",
        "requestId": context.invocation_id if hasattr(context, 'invocation_id') else 'unknown'
    }))

    try:
        body = json.loads(event.get('body', '{}'))
        symptoms = body.get('symptoms')
        
        if not symptoms:
            return {'statusCode': 400, 'headers': HEADERS, 'body': json.dumps({'message': 'Missing symptoms'})}

        # System Prompt for Safety
        system_prompt = """
        You are a medical symptom assessment assistant. 
        Guidelines:
        - Ask clarifying questions.
        - Assess severity (1-10).
        - Recommend: Self-care, Telemedicine, or ER.
        - NEVER prescribe medication.
        - Disclaimer: "This is not a diagnosis. Consult a doctor."
        """

        response = openai.ChatCompletion.create(
            engine=deployment_name,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": symptoms}
            ],
            temperature=0.3, # Low temperature for consistency
            max_tokens=500
        )

        content = response.choices[0].message['content']

        return {
            'statusCode': 200,
            'headers': HEADERS,
            'body': json.dumps({'assessment': content})
        }

    except Exception as e:
        logger.error(json.dumps({
            "level": "ERROR",
            "message": "Symptom Checker Error",
            "error": str(e)
        }))
        return {
            'statusCode': 500,
            'headers': HEADERS,
            'body': json.dumps({'message': 'Internal Server Error'})
        }
