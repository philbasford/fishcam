import os
import pytest
import logging
import greengrasssdk

from mock import patch, call
from core import process

logging.basicConfig(level=logging.INFO)

LOGGING = logging.getLogger(__name__)

def test_process():
    
    ipc_client = greengrasssdk.client("iot-data")

    os.environ['TEMP_PATH'] = 'tests/'

    ret = process(ipc_client)
    
    assert ret == {'sensor_id': '28-00000001e2d1', 'temperature': 23.562}