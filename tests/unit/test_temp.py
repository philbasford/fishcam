import json

import pytest
import logging
from temp import gettemp

logging.basicConfig(level=logging.INFO)

LOGGING = logging.getLogger(__name__)


def test_gettemp():

    # Script has been called directly
    sensor_id = '28-00000001e2d1'
    value = gettemp(sensor_id, 'tests/')
    temp = "Temp : {:.3f}".format(value/float(1000))
    
    LOGGING.info(temp)
    assert value == float(23562)