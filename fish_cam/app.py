import signal
import sys
import logging
import time
import greengrasssdk
from core import process

LOGGER = logging.getLogger(__name__)


def lambda_handler(event, context):
    """Sample pure Lambda function

    Parameters
    ----------
    event: dict, required
        API Gateway Lambda Proxy Input Format

        Event doc: https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-lambda-proxy-integrations.html#api-gateway-simple-proxy-for-lambda-input-format

    context: object, required
        Lambda Context runtime methods and attributes

        Context doc: https://docs.aws.amazon.com/lambda/latest/dg/python-context-object.html

    Returns
    ------
    API Gateway Lambda Proxy Output Format: dict

        Return doc: https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-lambda-proxy-integrations.html

        temporary
    """
    iot_client = greengrasssdk.client('iot-data')

    return process(iot_client)


class SIGINTHandler():
    def __init__(self):
        self.SIGINT = False

    def signal_handler(self, signal, frame):
        LOGGER.info('You pressed Ctrl+C!')
        self.SIGINT = True


def main():
    """Entry point for container to start from.
    """
    logging.basicConfig(level=logging.INFO)

    LOGGER.info("Starting signal")
    handler = SIGINTHandler()
    signal.signal(signal.SIGINT, handler.signal_handler)
    signal.signal(signal.SIGTERM, handler.signal_handler)

    try:
        # Let's instantiate the iot-data client
        iot_client = greengrasssdk.client('iot-data')

        while True:

            LOGGER.info("process")
            process(iot_client)

            # task
            if handler.SIGINT:
                break

            time.sleep(2.4)

        LOGGER.info("Completed")
        sys.exit(0)

    except Exception as e:
        LOGGER.exception(e)
        sys.exit(-1)


main()
