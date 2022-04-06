import logging

LOGGING = logging.getLogger(__name__)


def gettemp(sensor_id, path):
    try:
        mytemp = ''
        filename = 'w1_slave'
        f = open(path + sensor_id + '/' + filename, 'r')
        line = f.readline()  # read 1st line
        crc = line.rsplit(' ', 1)
        crc = crc[1].replace('\n', '')
        if crc == 'YES':
            line = f.readline()  # read 2nd line
            mytemp = line.rsplit('t=', 1)
        else:
            mytemp = 99999
        f.close()

        return int(mytemp[1])

    except Exception as e:
        LOGGING.exception(e)
        return 99999
