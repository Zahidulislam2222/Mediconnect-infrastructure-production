const AWS = require('aws-sdk');
const { v4: uuidv4 } = require('uuid');

const chime = new AWS.Chime({ region: 'us-east-1' }); // Chime is global/us-east-1
const chimemeetings = new AWS.ChimeSDKMeetings({ region: 'us-east-1' });

const HEADERS = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
    'Strict-Transport-Security': 'max-age=31536000; includeSubDomains; preload',
    'X-Content-Type-Options': 'nosniff',
    'Content-Type': 'application/json'
};

exports.handler = async (event) => {
    // Audit Logging (No PII)
    console.log(JSON.stringify({
        level: 'INFO',
        message: 'Video Service Invoked',
        requestId: event.requestContext?.requestId,
        path: event.path,
        method: event.httpMethod
    }));

    try {
        if (event.httpMethod === 'POST' && event.path === '/meeting') {
            return await createMeeting(event);
        } else if (event.httpMethod === 'POST' && event.path === '/attendee') {
            return await createAttendee(event);
        } else {
            return {
                statusCode: 404,
                headers: HEADERS,
                body: JSON.stringify({ message: 'Not Found' })
            };
        }
    } catch (error) {
        console.error(JSON.stringify({
            level: 'ERROR',
            message: 'Video Service Error',
            error: error.message, // Ensure no PII in error message
            requestId: event.requestContext?.requestId
        }));
        return {
            statusCode: 500,
            headers: HEADERS,
            body: JSON.stringify({ message: 'Internal Server Error' })
        };
    }
};

async function createMeeting(event) {
    const requestId = uuidv4();
    const region = 'us-east-1'; // Could be dynamic based on latency

    const meetingResponse = await chimemeetings.createMeeting({
        ClientRequestToken: requestId,
        MediaRegion: region,
        ExternalMeetingId: requestId // Map to appointment ID in production
    }).promise();

    return {
        statusCode: 201,
        headers: HEADERS,
        body: JSON.stringify(meetingResponse.Meeting)
    };
}

async function createAttendee(event) {
    const body = JSON.parse(event.body);
    const meetingId = body.meetingId;
    const externalUserId = body.externalUserId; // UUID of user from Cognito

    if (!meetingId || !externalUserId) {
        return {
            statusCode: 400,
            headers: HEADERS,
            body: JSON.stringify({ message: 'Missing meetingId or externalUserId' })
        };
    }

    const attendeeResponse = await chimemeetings.createAttendee({
        MeetingId: meetingId,
        ExternalUserId: externalUserId
    }).promise();

    return {
        statusCode: 201,
        headers: HEADERS,
        body: JSON.stringify(attendeeResponse.Attendee)
    };
}
