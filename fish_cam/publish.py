import json
import logging
import greengrasssdk

TIMEOUT = 10
LOGGING = logging.getLogger(__name__)
TOPIC = "fishcam/temperature"
QOS = 0  # AT_LEAST_ONCE


def send_message(iot_client: greengrasssdk.IoTDataPlane.Client, message: dict, topic=TOPIC):

    iot_client.publish(
        topic=topic,
        payload=json.dumps(message).encode("utf-8")
    )
