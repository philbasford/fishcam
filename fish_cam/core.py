import os
import logging
from greengrasssdk.IoTDataPlane import Client
from temp import gettemp
from publish import send_message

LOGGER = logging.getLogger(__name__)


def process(iot_client: Client):

    # conh
    sensor_id = os.getenv('TEMP_ID', '28-00000001e2d1')
    path = os.getenv('TEMP_PATH', '/sys/bus/w1/devices/')

    temperature = gettemp(sensor_id, path) / float(1000)
    msg = {
        'sensor_id': sensor_id,
        'temperature': temperature
    }

    send_message(iot_client, msg)

    return msg
